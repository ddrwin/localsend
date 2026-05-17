import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:common/model/device.dart';
import 'package:common/model/file_type.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/model/persistence/send_history_entry.dart';
import 'package:localsend_app/pages/send_history_page.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Result from [MessageInputDialog].
class MessageInputResult {
  final String text;
  final bool sendToAll;

  const MessageInputResult(this.text, this.sendToAll);
}

enum _SendMode { favorites, select, all }

class MessageInputDialog extends StatefulWidget {
  final String? initialText;
  final Ref ref;

  const MessageInputDialog({this.initialText, required this.ref});

  @override
  State<MessageInputDialog> createState() => _MessageInputDialogState();
}

class _MessageInputDialogState extends State<MessageInputDialog> {
  final _textController = TextEditingController();
  _SendMode _sendMode = _SendMode.select;
  bool _locked = false;
  bool _isSending = false;
  bool _autoSendOnPaste = false;
  Timer? _draftTimer;
  String _lastSavedDraft = '';

  @override
  void initState() {
    super.initState();
    _textController.text = widget.initialText ?? '';
    _restoreConfig();
    // Restore draft if no initial text was provided
    if (widget.initialText == null) {
      _restoreDraft();
    }
    // Start draft auto-save timer (every 1 second)
    _draftTimer = Timer.periodic(const Duration(seconds: 1), (_) => _saveDraft());
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _restoreConfig() {
    final raw = widget.ref.read(persistenceProvider).getMessageInputConfig();
    if (raw.isEmpty || raw == '{}') return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _sendMode = _SendMode.values.firstWhereOrNull((m) => m.name == map['sendMode']) ?? _SendMode.select;
      _locked = map['locked'] as bool? ?? false;
    } catch (_) {}
    _autoSendOnPaste = widget.ref.read(persistenceProvider).isAutoSendOnPaste();
  }

  void _saveConfig() {
    final json = jsonEncode({'sendMode': _sendMode.name, 'locked': _locked});
    widget.ref.read(persistenceProvider).setMessageInputConfig(json);
  }

  /// Restore the last draft from send history (the most recent draft entry).
  void _restoreDraft() {
    try {
      final persistence = widget.ref.read(persistenceProvider);
      final entries = persistence.getSendHistory();
      final lastDraft = entries.firstWhereOrNull((e) => e.isDraftValue);
      if (lastDraft != null) {
        _textController.text = lastDraft.fileName;
        _textController.selection = TextSelection.fromPosition(
          TextPosition(offset: lastDraft.fileName.length),
        );
        _lastSavedDraft = lastDraft.fileName;
      }
    } catch (_) {}
  }

  /// Auto-save draft every 1 second.
  /// Keeps at most one draft entry — updates in place if one exists.
  void _saveDraft() {
    try {
      final text = _textController.text.trim();
      if (text.isEmpty || text == _lastSavedDraft || _isSending) return;
      _lastSavedDraft = text;

      final persistence = widget.ref.read(persistenceProvider);
      final entries = persistence.getSendHistory();
      final existing = entries.firstWhereOrNull((e) => e.isDraftValue);

      if (existing != null) {
        // Update existing draft in place and move it to the front
        final updated = existing.copyWith(
          fileName: text,
          timestamp: DateTime.now().toUtc(),
        );
        final withoutDraft = entries.where((e) => e.id != existing.id).toList();
        unawaited(persistence.setSendHistory([updated, ...withoutDraft].take(30).toList()));
      } else {
        // First draft — create new entry
        final draft = SendHistoryEntry(
          id: _uuid.v4(),
          fileName: text,
          fileType: FileType.text,
          fileSize: 0,
          targetAlias: '',
          timestamp: DateTime.now().toUtc(),
          isDraft: true,
        );
        unawaited(persistence.setSendHistory([draft, ...entries].take(30).toList()));
      }
    } catch (_) {}
  }

  /// Remove the draft entry after sending.
  void _removeDraft() {
    try {
      final text = _textController.text.trim();
      if (text.isEmpty) return;
      final persistence = widget.ref.read(persistenceProvider);
      final entries = persistence.getSendHistory();
      unawaited(persistence.setSendHistory(entries.where((e) => !e.isDraftValue || e.fileName != text).toList()));
    } catch (_) {}
  }

  void _toggleAutoSend() {
    _autoSendOnPaste = !_autoSendOnPaste;
    widget.ref.notifier(settingsProvider).setAutoSendOnPaste(_autoSendOnPaste);
    setState(() {});
  }

  void _pop(String text, {bool sendToAll = false}) {
    Navigator.of(context).pop(MessageInputResult(text, sendToAll));
  }

  /// Create a single history entry with all targets (status = sending).
  /// Returns the entry ID so it can be updated after send completes.
  String _createHistoryEntry(String text, List<int> bytes, List<Device> targets) {
    try {
      final persistence = widget.ref.read(persistenceProvider);
      final id = _uuid.v4();
      final targetsData = targets.map((d) => {'alias': d.alias, 'status': 'sending'}).toList();
      final now = DateTime.now().toUtc();

      final newEntry = SendHistoryEntry(
        id: id,
        fileName: text,
        fileType: FileType.text,
        fileSize: bytes.length,
        targetAlias: targets.length == 1 ? targets.first.alias : '${targets.length} devices',
        timestamp: now,
        targetsJson: jsonEncode(targetsData),
      );

      final current = persistence.getSendHistory();
      unawaited(persistence.setSendHistory([newEntry, ...current].take(30).toList()));
      return id;
    } catch (_) {
      return '';
    }
  }

  /// Update per-target statuses in an existing history entry.
  void _updateTargetStatuses(String entryId, List<({Device device, bool success})> results) {
    try {
      if (entryId.isEmpty) return;
      final persistence = widget.ref.read(persistenceProvider);
      final entries = persistence.getSendHistory();
      final index = entries.indexWhere((e) => e.id == entryId);
      if (index < 0) return;

      final entry = entries[index];
      final existingTargets = entry.targetsJson != null
          ? (jsonDecode(entry.targetsJson!) as List<dynamic>).cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];

      for (final r in results) {
        final t = existingTargets.firstWhereOrNull((t) => t['alias'] == r.device.alias);
        if (t != null) {
          t['status'] = r.success ? 'success' : 'failed';
        }
      }

      final updated = entry.copyWith(targetsJson: jsonEncode(existingTargets));
      final newList = [...entries];
      newList[index] = updated;
      unawaited(persistence.setSendHistory(newList));
    } catch (_) {}
  }

  /// Send text to the given devices in the background.
  /// Returns per-target results.
  Future<List<({Device device, bool success})>> _sendToDevices(
    Iterable<Device> targets, String text, List<int> bytes,
  ) async {
    if (_isSending) return [];
    if (targets.isEmpty) return [];

    final autoPaste = _autoSendOnPaste; // capture current state for the flag
    final file = CrossFile(
      name: '${_uuid.v4()}.txt',
      fileType: FileType.text,
      size: bytes.length,
      thumbnail: null,
      asset: null,
      path: null,
      bytes: bytes,
      lastModified: null,
      lastAccessed: null,
      autoPaste: autoPaste,
    );

    final ref = widget.ref;
    final devices = targets.toList();

    _isSending = true;
    try {
      final results = await Future.wait(devices.map((d) async {
        try {
          await ref.notifier(sendProvider).startSession(
            target: d,
            files: [file],
            background: true,
            skipRecording: true, // dialog handles history
          );
          return (device: d, success: true);
        } catch (_) {
          return (device: d, success: false);
        }
      }));

      if (mounted) {
        _showTopToast(t.general.finished);
      }
      return results;
    } finally {
      _isSending = false;
    }
  }

  void _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final bytes = utf8.encode(text);

    switch (_sendMode) {
      case _SendMode.favorites: {
        final ref = widget.ref;
        final nearbyDevices = ref.read(nearbyDevicesProvider).devices.values;
        final favorites = ref.read(favoritesProvider);
        final targets = <Device>[];
        for (final favorite in favorites) {
          final device = nearbyDevices.firstWhereOrNull((d) => d.fingerprint == favorite.fingerprint);
          if (device != null) targets.add(device);
        }
        if (targets.isEmpty) return;

        // Remove draft, create single history entry, then send
        _removeDraft();
        final entryId = _createHistoryEntry(text, bytes, targets);
        final results = await _sendToDevices(targets, text, bytes);
        _updateTargetStatuses(entryId, results);

        _textController.clear();
        _lastSavedDraft = '';
        if (!_locked) {
          _pop(text);
        }
      }

      case _SendMode.select: {
        _removeDraft();
        _textController.clear();
        _lastSavedDraft = '';
        _pop(text);
      }

      case _SendMode.all: {
        final ref = widget.ref;
        final targets = ref.read(nearbyDevicesProvider).devices.values;
        if (targets.isEmpty) return;

        // Remove draft, create single history entry, then send
        _removeDraft();
        final entryId = _createHistoryEntry(text, bytes, targets.toList());
        final results = await _sendToDevices(targets, text, bytes);
        _updateTargetStatuses(entryId, results);

        _textController.clear();
        _lastSavedDraft = '';
        if (!_locked) {
          _pop(text, sendToAll: true);
        }
      }
    }
  }

  void _showTopToast(String message) {
    final overlay = Navigator.of(context, rootNavigator: true).overlay;
    if (overlay == null) return;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _ToastWidget(
        message: message,
        onDismiss: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canLock = _sendMode != _SendMode.select;

    return AlertDialog(
      titlePadding: const EdgeInsets.only(top: 16, left: 24, right: 24),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Utility icons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Auto-send toggle
              IconButton(
                padding: EdgeInsets.zero,
                iconSize: 20,
                icon: Icon(_autoSendOnPaste ? Icons.send : Icons.send_outlined),
                color: _autoSendOnPaste ? theme.colorScheme.primary : null,
                onPressed: _toggleAutoSend,
                tooltip: t.settingsTab.receive.autoSendOnPaste,
              ),
              // Lock toggle
              Opacity(
                opacity: canLock ? 1.0 : 0.3,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  icon: Icon(_locked ? Icons.lock : Icons.lock_open),
                  color: _locked ? theme.colorScheme.primary : null,
                  onPressed: canLock ? () => setState(() {
                    _locked = !_locked;
                    _saveConfig();
                  }) : null,
                  tooltip: t.general.lock,
                ),
              ),
              // History
              IconButton(
                padding: EdgeInsets.zero,
                iconSize: 20,
                icon: const Icon(Icons.history),
                onPressed: () async {
                  final text = await Navigator.of(context, rootNavigator: true).push<String>(
                    MaterialPageRoute(builder: (_) => const SendHistoryPage()),
                  );
                  if (text != null && mounted) {
                    _textController.text = text;
                    _textController.selection = TextSelection.fromPosition(
                      TextPosition(offset: text.length),
                    );
                  }
                },
                tooltip: t.sendHistoryPage.title,
              ),
              // Close
              IconButton(
                padding: EdgeInsets.zero,
                iconSize: 20,
                icon: const Icon(Icons.close),
                onPressed: () => context.pop(),
                tooltip: t.general.cancel,
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Row 2: Mode selector — favorites / all, centered
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ModeChip(
                icon: Icons.star,
                label: t.dialogs.messageInput.modeFavorites,
                selected: _sendMode == _SendMode.favorites,
                selectedColor: Colors.amber,
                onTap: () => setState(() {
                  if (_sendMode != _SendMode.favorites) {
                    final favorites = widget.ref.read(favoritesProvider);
                    if (favorites.isEmpty) return; // no favorites configured
                  }
                  _sendMode = _sendMode == _SendMode.favorites ? _SendMode.select : _SendMode.favorites;
                  _saveConfig();
                }),
              ),
              const SizedBox(width: 8),
              _ModeChip(
                icon: Icons.wifi_tethering,
                label: t.dialogs.messageInput.modeAll,
                selected: _sendMode == _SendMode.all,
                selectedColor: const Color(0xFF4995ED),
                onTap: () => setState(() {
                  _sendMode = _sendMode == _SendMode.all ? _SendMode.select : _SendMode.all;
                  _saveConfig();
                }),
              ),
            ],
          ),
        ],
      ),
      content: TextFormField(
        controller: _textController,
        decoration: InputDecoration(
          hintText: t.dialogs.messageInput.title,
          border: InputBorder.none,
        ),
        keyboardType: TextInputType.multiline,
        minLines: 10,
        maxLines: null,
        autofocus: true,
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                onPressed: _handleSend,
                icon: Icon(_sendModeIcon, size: 18),
                label: Text(_sendModeLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }

  IconData get _sendModeIcon {
    switch (_sendMode) {
      case _SendMode.favorites:
        return Icons.star;
      case _SendMode.select:
        return Icons.touch_app;
      case _SendMode.all:
        return Icons.wifi_tethering;
    }
  }

  String get _sendModeLabel {
    switch (_sendMode) {
      case _SendMode.favorites:
        return t.dialogs.messageInput.sendToFavorites;
      case _SendMode.select:
        return t.dialogs.messageInput.sendToSelected;
      case _SendMode.all:
        return t.dialogs.messageInput.sendToAll;
    }
  }
}

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _ModeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? selectedColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? selectedColor : theme.dividerColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? selectedColor : null),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected ? selectedColor : null,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated toast widget displayed via [OverlayEntry].
class _ToastWidget extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ToastWidget({required this.message, required this.onDismiss});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 10;
    return AnimatedBuilder(
      animation: _controller,
      builder: (ctx, _) => Positioned(
        top: top,
        left: 0,
        right: 0,
        child: Opacity(
          opacity: _opacity.value,
          child: SlideTransition(
            position: _slide,
            child: Center(
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.message,
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.onSurface,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
