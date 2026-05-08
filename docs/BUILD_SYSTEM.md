# LocalSend Windows 构建系统说明

## 构建环境

当前构建环境基于 MSVC 2026 BuildTools + Ninja + 独立 CMake 3.31.6。

## 已知问题

### Ninja 单配置生成器 + `$<CONFIG>` 空字符串 BUG

**根因：** Flutter 的 `windows/flutter/CMakeLists.txt` 第 100 行使用 CMake 生成器表达式 `$<CONFIG>` 来确定构建模式：

```cmake
"${FLUTTER_ROOT}/packages/flutter_tools/bin/tool_backend.bat"
  ${FLUTTER_TARGET_PLATFORM} $<CONFIG>
```

在 MSBuild（VS 生成器，multi-config）下 `$<CONFIG>` 会求值为 `Release`/`Debug`。
在 **Ninja**（single-config）下 `$<CONFIG>` 求值为**空字符串**。

导致 `tool_backend.bat` 收到空参数，组装了错误的 Flutter 引擎变体（debug 45MB 而非 release 18MB），进而引发 TLS 握手失败。

**修复方式：** 修改 Flutter SDK 的 `build_windows.dart`，在 `_runCmakeGeneration` 中对 Ninja 生成器额外传入 `-DCMAKE_BUILD_TYPE=Release`。

**补丁文件：** `docs/patches/flutter_build_windows_ninja_cmake_type.patch`

**受影响版本：** 所有使用 Ninja 生成器的 Flutter Windows 构建（Flutter 3.24.x）。

**验证方法：**
```bash
# 检查 Flutter 引擎 DLL 大小
ls -la windows/flutter/ephemeral/flutter_windows.dll
# 18MB = Release ✅  45MB = Debug ❌
```

## 构建脚本

| 脚本 | 用途 | 说明 |
|------|------|------|
| `build_windows.bat` | Ninja + MSVC 2026 构建 | 当前主要构建方式 |
| `build_vs.bat` | VS 生成器构建 | 需要 VS 2022 或更新版本 |
| `build_android.bat` | Android APK 构建 | 调用 flutter build apk |

## 构建产物

构建产物统一归档到 `E:\CodeBase\build_outputs\LocalSend\`，命名规范：
```
LocalSend_简短描述_YYYYMMDD_HHMMSS\
```

详见 `E:\CodeBase\build_outputs\BUILD_LOG.md`。
