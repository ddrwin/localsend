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
  final bool? isDraft; // null = false (backward compat)
  final String? targetsJson; // JSON: [{"alias":"张三","status":"success|failed|sending"},...]

  const SendHistoryEntry({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.targetAlias,
    required this.timestamp,
    this.isDraft,
    this.targetsJson,
  });

  bool get isDraftValue => isDraft ?? false;

  String get timestampString {
    final localTimestamp = timestamp.toLocal();
    final languageTag = LocaleSettings.currentLocale.languageTag;
    return '${DateFormat.yMd(languageTag).format(localTimestamp)} ${DateFormat.jm(languageTag).format(localTimestamp)}';
  }

  static const fromJson = SendHistoryEntryMapper.fromJson;
}
