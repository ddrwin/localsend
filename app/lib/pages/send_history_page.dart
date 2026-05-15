import 'package:common/model/file_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/send_history_entry.dart';
import 'package:localsend_app/pages/send_text_view_page.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:localsend_app/util/file_size_helper.dart';
import 'package:localsend_app/widget/dialogs/send_file_info_dialog.dart';
import 'package:localsend_app/widget/file_thumbnail.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';

enum _EntryOption {
  copy,
  resend,
  view,
  info,
  delete;

  String get label {
    return switch (this) {
      _EntryOption.copy => t.sendHistoryPage.entryActions.copy,
      _EntryOption.resend => t.sendHistoryPage.entryActions.resend,
      _EntryOption.view => t.sendHistoryPage.entryActions.view,
      _EntryOption.info => t.sendHistoryPage.entryActions.info,
      _EntryOption.delete => t.sendHistoryPage.entryActions.deleteFromHistory,
    };
  }
}

final _optionsText = [_EntryOption.copy, _EntryOption.resend, _EntryOption.view, _EntryOption.delete];
final _optionsFile = [_EntryOption.info, _EntryOption.delete];

class SendHistoryPage extends StatefulWidget {
  const SendHistoryPage({super.key});

  @override
  State<SendHistoryPage> createState() => _SendHistoryPageState();
}

class _SendHistoryPageState extends State<SendHistoryPage> {
  List<SendHistoryEntry> _entries = const <SendHistoryEntry>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEntries());
  }

  void _loadEntries() {
    if (!mounted) return;
    setState(() {
      _entries = context.read(persistenceProvider).getSendHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.sendHistoryPage.title),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final result = await showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(t.dialogs.historyClearDialog.title),
                    content: Text(t.dialogs.historyClearDialog.content),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(t.general.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(t.general.delete),
                      ),
                    ],
                  ),
                );
                if (context.mounted && result == true) {
                  final persistence = context.read(persistenceProvider);
                  await persistence.setSendHistory([]);
                  _loadEntries();
                }
              },
            ),
        ],
      ),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Center(
                child: Text(
                  t.sendHistoryPage.empty,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            )
          else
            ...entries.map((entry) {
              final isText = entry.fileType == FileType.text;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                child: InkWell(
                  splashColor: Colors.transparent,
                  splashFactory: NoSplash.splashFactory,
                  highlightColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  onTap: isText
                      ? () async {
                          await Clipboard.setData(ClipboardData(text: entry.fileName));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(t.general.copiedToClipboard)),
                            );
                          }
                        }
                      : null,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FilePathThumbnail(
                        path: null,
                        fileType: entry.fileType,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 3),
                            Text(
                              entry.fileName,
                              style: const TextStyle(fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                            ),
                            Text(
                              '${entry.timestampString} - ${entry.fileSize.asReadableFileSize} - ${entry.targetAlias}',
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      PopupMenuButton<_EntryOption>(
                        onSelected: (_EntryOption item) async {
                          switch (item) {
                            case _EntryOption.copy:
                              await Clipboard.setData(ClipboardData(text: entry.fileName));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(t.general.copiedToClipboard)),
                                );
                              }
                            case _EntryOption.resend:
                              // Pop back to send_tab with the text
                              Navigator.of(context).pop(entry.fileName);
                            case _EntryOption.view:
                              // ignore: use_build_context_synchronously
                              await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => SendTextViewPage(text: entry.fileName)),
                              );
                            case _EntryOption.info:
                              // ignore: use_build_context_synchronously
                              await showDialog(
                                context: context,
                                builder: (_) => SendFileInfoDialog(entry: entry),
                              );
                            case _EntryOption.delete:
                              final persistence = context.read(persistenceProvider);
                              final updated = [..._entries]..removeWhere((e) => e.id == entry.id);
                              await persistence.setSendHistory(updated);
                              _loadEntries();
                          }
                        },
                        itemBuilder: (BuildContext context) {
                          return (isText ? _optionsText : _optionsFile).map((e) {
                            return PopupMenuItem<_EntryOption>(
                              value: e,
                              child: Text(e.label),
                            );
                          }).toList();
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
