---
name: 2026-05-08 TLS handshake EOF 修复 — Ninja $<CONFIG> 空字符串 BUG
description: Ninja 单配置生成器下 $<CONFIG> 求值为空，Flutter 引擎变体错误导致 TLS 握手失败，以及构建产物归档规范的建立
type: project
---

# 2026-05-08 TLS handshake EOF 修复与构建产物归档规范

## 问题

VS 2022 删除后改用 Ninja + MSVC 2026 构建，新编译的 Windows 安装包出现 TLS handshake EOF 错误。

**错误信息：**
```
RhttpConnectionException] Connection error. URL: https://192.168.50.33:53317/...
(hyper_util::client::legacy::Error(Connect, Custom { kind: UnexpectedEof, error: "tls handshake eof" }))
```

## 诊断过程

| 步骤 | 发现 |
|------|------|
| 比较 VS 2022 构建（正常）和 Ninja 构建（异常） | VS 2022 版本 TLS 正常 |
| 检查 flutter_windows.dll | 正常版：18MB（release），异常版：45MB（debug） |
| 检查 CMakeLists.txt | `$<CONFIG>` 生成器表达式 |
| 检查 Ninja 行为 | 单配置生成器下 `$<CONFIG>` 求值为空 |
| 跟踪 tool_backend.bat | 收到空构建模式参数 → 组装了 debug 引擎 |

## 根因

```
Ninja (single-config generator)
  → $<CONFIG> 在 CMake 中求值为 ""（空字符串）
  → CMakeLists.txt:100: tool_backend.bat ${FLUTTER_TARGET_PLATFORM} $<CONFIG>
  → tool_backend.bat 收到: "windows-x64 "（第二个参数为空）
  → 组装了 debug Flutter 引擎变体（45MB vs 18MB）
  → debug 引擎的 TLS 处理行为不同 → tls handshake eof
```

## 修复

修改 `C:\flutter\flutter\packages\flutter_tools\lib\src\windows\build_windows.dart`：

1. `_runCmakeGeneration` 函数新增 `buildModeName` 参数
2. 当 `generator == 'Ninja'` 时传入 `-DCMAKE_BUILD_TYPE=Release`

## 验证

```bash
md5sum windows/flutter/ephemeral/flutter_windows.dll
# Release: 225782e5d02f400a76b8fabe8a6f5cd1 (18MB)
# Debug:   b93ff2abe12a2cff3f13663c528c0294 (45MB)
```

## 构建产物归档规范（新建立）

- 所有构建产物统一归到 `E:\CodeBase\build_outputs\`
- LocalSend 项目产物在 `E:\CodeBase\build_outputs\LocalSend\`
- 命名：`LocalSend_简短描述_YYYYMMDD_HHMMSS`
- 每个目录有 README.md 描述
- 根目录有 BUILD_LOG.md 汇总日志

## 上游关联

- GitHub issue: https://github.com/localsend/localsend/issues/3028
- Flutter SDK 修改位置：`packages/flutter_tools/lib/src/windows/build_windows.dart`
- 项目构建脚本：`build_windows.bat`
