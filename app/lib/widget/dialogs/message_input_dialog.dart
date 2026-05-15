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

  @override
  void initState() {
    super.initState();
    _textController.text = widget.initialText ?? '';
    _restoreConfig();
  }

  @override
  void dispose() {
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
  }

  void _saveConfig() {
    final json = jsonEncode({'sendMode': _sendMode.name, 'locked': _locked});
    widget.ref.read(persistenceProvider).setMessageInputConfig(json);
  }

  void _pop(String text, {bool sendToAll = false}) {
    Navigator.of(context).pop(MessageInputResult(text, sendToAll));
  }

  /// Send text to the given devices, record history, and handle lock behavior.
  Future<void> _sendToDevices(Iterable<Device> targets, String text, List<int> bytes) async {
    if (_isSending) return;
    if (targets.isEmpty) return;

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
    );

    final ref = widget.ref;
    final devices = targets.toList();

    _isSending = true;
    try {
      await Future.wait(devices.map((d) => ref.notifier(sendProvider).startSession(
        target: d,
        files: [file],
        background: true,
      )));

      // Record send history
      try {
        final persistence = ref.read(persistenceProvider);
        final now = DateTime.now().toUtc();
        for (final device in devices) {
          final newEntry = SendHistoryEntry(
            id: _uuid.v4(),
            fileName: text,
            fileType: FileType.text,
            fileSize: bytes.length,
            targetAlias: device.alias,
            timestamp: now,
          );
          final current = persistence.getSendHistory();
          await persistence.setSendHistory([newEntry, ...current].take(30).toList());
        }
      } catch (_) {}

      if (mounted) {
        _showTopToast(t.general.finished);
      }
    } finally {
      _isSending = false;
    }
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final bytes = utf8.encode(text);

    switch (_sendMode) {
      case _SendMode.favorites:
        final ref = widget.ref;
        final nearbyDevices = ref.read(nearbyDevicesProvider).devices.values;
        final favorites = ref.read(favoritesProvider);
        final targets = <Device>[];
        for (final favorite in favorites) {
          final device = nearbyDevices.firstWhereOrNull((d) => d.fingerprint == favorite.fingerprint);
          if (device != null) targets.add(device);
        }
        if (targets.isEmpty) return;

        if (_locked) {
          _sendToDevices(targets, text, bytes);
          _textController.clear();
        } else {
          _sendToDevices(targets, text, bytes);
          _textController.clear();
          _pop(text);
        }

      case _SendMode.select:
        _pop(text);

      case _SendMode.all:
        final ref = widget.ref;
        final targets = ref.read(nearbyDevicesProvider).devices.values;
        if (targets.isEmpty) return;

        if (_locked) {
          _sendToDevices(targets, text, bytes);
          _textController.clear();
        } else {
          _sendToDevices(targets, text, bytes);
          _textController.clear();
          _pop(text, sendToAll: true);
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
          // Row 1: Title + utility icons
          Row(
            children: [
              Expanded(child: Text(t.dialogs.messageInput.title, style: const TextStyle(fontSize: 14))),
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
          // Row 2: Mode selector — favorites / all only, centered
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ModeChip(
                icon: Icons.star,
                label: t.dialogs.messageInput.modeFavorites,
                selected: _sendMode == _SendMode.favorites,
                selectedColor: Colors.amber,
                onTap: () => setState(() {
                  _sendMode = _sendMode == _SendMode.favorites ? _SendMode.select : _SendMode.favorites;
                  _saveConfig();
                }),
              ),
              const SizedBox(width: 8),
              _ModeChip(
                icon: Icons.wifi_tethering,
                label: t.dialogs.messageInput.modeAll,
                selected: _sendMode == _SendMode.all,
                selectedColor: Colors.green,
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
