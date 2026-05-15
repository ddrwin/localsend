import 'package:common/model/file_type.dart';
import 'package:localsend_app/model/persistence/send_history_entry.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

const _maxHistoryEntries = 30;

final sendHistoryProvider = ReduxProvider<SendHistoryService, List<SendHistoryEntry>>((ref) {
  return SendHistoryService(ref.read(persistenceProvider));
});

class SendHistoryService extends ReduxNotifier<List<SendHistoryEntry>> {
  final PersistenceService _persistence;

  SendHistoryService(this._persistence);

  @override
  List<SendHistoryEntry> init() => _persistence.getSendHistory();

  /// Reload state from persistence and notify watchers.
  void reload() {
    state = _persistence.getSendHistory();
  }
}

class AddSendHistoryEntryAction extends AsyncReduxAction<SendHistoryService, List<SendHistoryEntry>> {
  final String entryId;
  final String fileName;
  final FileType fileType;
  final int fileSize;
  final String targetAlias;
  final DateTime timestamp;

  AddSendHistoryEntryAction({
    required this.entryId,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.targetAlias,
    required this.timestamp,
  });

  @override
  Future<List<SendHistoryEntry>> reduce() async {
    final updated = [
      SendHistoryEntry(
        id: entryId,
        fileName: fileName,
        fileType: fileType,
        fileSize: fileSize,
        targetAlias: targetAlias,
        timestamp: timestamp,
      ),
      ...state,
    ].take(_maxHistoryEntries).toList();
    await notifier._persistence.setSendHistory(updated);
    return updated;
  }
}

class RemoveSendHistoryEntryAction extends AsyncReduxAction<SendHistoryService, List<SendHistoryEntry>> {
  final String entryId;

  RemoveSendHistoryEntryAction(this.entryId);

  @override
  Future<List<SendHistoryEntry>> reduce() async {
    final index = state.indexWhere((e) => e.id == entryId);
    if (index == -1) {
      return state;
    }
    final updated = [...state]..removeAt(index);
    await notifier._persistence.setSendHistory(updated);
    return updated;
  }
}

class RemoveAllSendHistoryEntriesAction extends AsyncReduxAction<SendHistoryService, List<SendHistoryEntry>> {
  @override
  Future<List<SendHistoryEntry>> reduce() async {
    await notifier._persistence.setSendHistory([]);
    return [];
  }
}
