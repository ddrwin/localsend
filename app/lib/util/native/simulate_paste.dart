import 'package:flutter/services.dart';
import '../platform_check.dart';

const _channel = MethodChannel('localsend/paste');

/// 模拟粘贴（仅 Windows）：复制到剪贴板后调用此函数模拟 Ctrl+V
Future<bool> simulatePaste() async {
  if (!checkPlatformIsWindows()) return false;
  try {
    await _channel.invokeMethod<bool>('simulatePaste');
    return true;
  } catch (_) {
    return false;
  }
}
