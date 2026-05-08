import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:routerino/routerino.dart';

/// Result from [MessageInputDialog].
/// [text] is always non-null when [okay] is true.
/// [sendToAll] is true when the user chose "Send to all devices".
class MessageInputResult {
  final String text;
  final bool sendToAll;

  const MessageInputResult(this.text, this.sendToAll);
}

class MessageInputDialog extends StatefulWidget {
  final String? initialText;

  const MessageInputDialog({this.initialText});

  @override
  State<MessageInputDialog> createState() => _MessageInputDialogState();
}

class _MessageInputDialogState extends State<MessageInputDialog> {
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _textController.text = widget.initialText ?? '';
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _pop(String text, {bool sendToAll = false}) {
    Navigator.of(context).pop(MessageInputResult(text, sendToAll));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(t.dialogs.messageInput.title)),
          SizedBox(
            width: 36,
            height: 36,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 20,
              icon: const Icon(Icons.close),
              onPressed: () => context.pop(),
              tooltip: t.general.cancel,
            ),
          ),
        ],
      ),
      content: TextFormField(
        controller: _textController,
        keyboardType: TextInputType.multiline,
        maxLines: null,
        autofocus: true,
      ),
      actions: [
        Row(
          children: [
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              onPressed: () => _pop(_textController.text, sendToAll: true),
              child: Text(t.dialogs.messageInput.sendToAll),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              onPressed: () => _pop(_textController.text),
              child: Text(t.general.confirm),
            ),
          ],
        ),
      ],
    );
  }
}
