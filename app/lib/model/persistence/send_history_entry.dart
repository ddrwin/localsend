import 'package:common/model/file_type.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:intl/intl.dart';
import 'package:localsend_app/gen/strings.g.dart';

part 'send_history_entry.mapper.dart';

@MappableClass()
class SendHistoryEntry with SendHistoryEntryMappable {
  final String id;
  final String fileName;
  final FileType fileType;
  final int fileSize;
  final String targetAlias;
  final DateTime timestamp;

  const SendHistoryEntry({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.targetAlias,
    required this.timestamp,
  });

  String get timestampString {
    final localTimestamp = timestamp.toLocal();
    final languageTag = LocaleSettings.currentLocale.languageTag;
    return '${DateFormat.yMd(languageTag).format(localTimestamp)} ${DateFormat.jm(languageTag).format(localTimestamp)}';
  }

  static const fromJson = SendHistoryEntryMapper.fromJson;
}
