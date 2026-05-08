---
name: 2026-05-08 下午 构建全记录#5 — 自动粘贴、PC同步、导入路径修复
description: 从 16:26 到 18:04 共发布 7 次构建（#5~#11），覆盖自动粘贴功能、PC端同步、bug修复、目录命名规范化
type: project
originSessionId: e8b0dde6-c272-4db9-9a4c-2bce7692d288
---

# 2026-05-08 下午 构建全记录 #5

## 时间线

| 时间 | 构建 | 内容 |
|------|------|------|
| 15:16 | #5 PC安装版_Ninja编译修复 | Flutter SDK `$<CONFIG>` 补丁，Release 引擎恢复 |
| 16:22 | #6 AndroidAPK_群发修复 | librhttp.so jniLibs 注入 + dependency_overrides |
| 16:50 | #7 AndroidAPK_按钮样式调整 | TextButton→ElevatedButton, 布局调整 |
| 17:04 | #8 AndroidAPK_按钮布局调整 | 取消移到 header, 详情页撑满 |
| 17:28 | #9 AndroidAPK_自动粘贴 | 自动粘贴 + 历史面板粘贴（含 bug） |
| 18:00 | #10 PC安装版_自动粘贴布局同步 | Windows 编译通过 |
| 18:04 | #11 AndroidAPK_修复导入路径SnackBar | 修复 #9 的两个 bug |

## 关键变更

### 1. 粘贴功能实现（方案A + 方案B）

**方案A — 收到文本自动粘贴：**
- 修改文件：`receive_controller.dart` — 在 `Clipboard.setData()` 后调用 `simulatePaste()`
- PC 端：SendInput Windows API（`flutter_window.cpp` 注册 MethodChannel `localsend/paste`）
- Android 端：`simulatePaste()` 返回 false → fallback 到显示"已复制到剪贴板"

**方案B — 历史面板粘贴：**
- 修改文件：`receive_history_page.dart`
- 直接点击消息条目 → `Clipboard.setData()` + `simulatePaste()`
- 菜单重构：粘贴内容 | 详细信息 | 删除

### 2. 按钮布局统一

- `message_input_dialog.dart`：取消移到标题栏右上角 ×，「发送到所有设备」居中 ElevatedButton，「确认」在右
- 共享代码，PC/Android 同时生效

### 3. 详情页文本区撑满

- `receive_page.dart`：`SizedBox(height:100)` → `Expanded`，Column 对齐改为 `start`

### 4. Windows 编译（#10）

- 问题：`flutter_windows.dll.lib` 在 ephemeral 中缺失
- 修复：手动从 `C:\Flutter\flutter\bin\cache\artifacts\engine\windows-x64-release\` 复制
- 引擎：✅ Release（18MB，MD5 `225782e5d02f400a76b8fabe8a6f5cd1`）

## Bug 复盘

### Bug 1：simulate_paste.dart 导入路径错误

提交 `fb0861c` 中存在：
```dart
import '../platform_check.dart';  // 错误路径
checkPlatformIsWindows();  // 不存在的函数
```
修复：
```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/util/native/platform_check.dart';
checkPlatform([TargetPlatform.windows]);
```

### Bug 2：showSnackBar 类型错误

```dart
// 错误：传入 SnackBar 对象，但接口期望 String
context.showSnackBar(SnackBar(content: Text(t.general.copiedToClipboard)));
// 正确
context.showSnackBar(t.general.copiedToClipboard);
```

这两个 bug 导致 v1.17.1-android-r3 在 Android 上粘贴功能异常。

## 目录命名规范化

按照要求，所有 build_output 目录统一为以下格式：

```
LocalSend_YYYYMMDD_HHMMSS_平台_类型_描述
```

平台：`PC` / `Android` / `PC便携版+AndroidAPK`（混合）
类型：`便携版`（散装 exe+dll） / `安装版`（Inno Setup 安装包） / `APK`（Android 安装包）

示例：
- `LocalSend_20260508_180000_PC安装版_自动粘贴布局同步`
- `LocalSend_20260508_181000_AndroidAPK_修复导入路径SnackBar`

## 待解决问题

### TLS handshake EOF（2026-05-08 18:30 发现）

**现象：** Windows 安装版（#10）连接 Android 设备时报错：
```
tls handshake eof
hyper_util::client::legacy::Error(Connect, Custom { kind: UnexpectedEof })
```

**排查过程：**
1. 旧版 Windows 便携版（#1、#2）同样报错 → 不是本次编译引入
2. 旧版 Android APK（#6、#7）同样报错 → 不是编译问题
3. `curl -k https://192.168.50.33:53317/` 正常（使用 schannel）→ 网络连通
4. 关键是：**旧 APK 以前能正常收发，现在也报错**

**结论：** 不是代码或编译问题，是环境变化导致。可能是：
- 被连接的 Android 设备（192.168.50.33）上的 LocalSend 被更新，TLS 配置变化
- rustls 与 Android 设备的新 TLS 配置不兼容

**与老 Bug（$<CONFIG>）的区别：**
- 老 Bug：编译时使用了 Debug 引擎（45MB），`flutter_windows.dll` 不对
- 本次：引擎正确（Release 18MB），是运行时 TLS 协商问题
