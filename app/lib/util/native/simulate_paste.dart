import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/util/native/platform_check.dart';

const _channel = MethodChannel('localsend/paste');

/// 模拟回车键（仅 Windows）：粘贴后调用此函数模拟 Enter 发送
Future<bool> simulateEnter() async {
  if (!checkPlatform([TargetPlatform.windows])) return false;
  try {
    await _channel.invokeMethod<bool>('simulateEnter');
    return true;
  } catch (_) {
    return false;
  }
}

/// 模拟粘贴（仅 Windows）：复制到剪贴板后调用此函数模拟 Ctrl+V
Future<bool> simulatePaste() async {
  if (!checkPlatform([TargetPlatform.windows])) return false;
  try {
    await _channel.invokeMethod<bool>('simulatePaste');
    return true;
  } catch (_) {
    return false;
  }
}
