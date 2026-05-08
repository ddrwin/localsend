---
name: 2026-05-08 Android librhttp.so 缺失修复 — cargokit pub cache bug
description: rhttp 0.10.0 在 pub cache 中 cargokit 的 build_tool runner 无法执行 dart pub get，导致 Android APK 缺少 librhttp.so
type: project
originSessionId: e8b0dde6-c272-4db9-9a4c-2bce7692d288
---

# 2026-05-08 Android librhttp.so 缺失修复

## 问题

`flutter build apk --split-per-abi --release` 构建的 APK 缺少 `librhttp.so`（3.8MB），APK 大小仅 15MB（应有 18MB+）。

**现象：** 构建速度极快（~6s），说明 cargokit 没有编译 Rust 原生代码。

## 诊断过程

| 步骤 | 发现 |
|------|------|
| 检查 APK 内容 | `unzip -l app-arm64-v8a-release.apk | grep librhttp` → 无输出 |
| 对比可用 APK | 2026-05-07 构建的 APK 包含 librhttp.so（3.8MB） |
| 检查 build/intermediates | merged_native_libs 中没有 librhttp.so |
| 检查构建日志 | 发现 cargokit 报错 `Cannot operate on packages inside the cache` |
| 检查 rhttp 位置 | `rhttp-0.10.0` 位于 pub cache `C:\Users\...\Pub\Cache\hosted\pub.dev\` |
| 检查 cargokit 流程 | cargokit 需要 run_build_tool.cmd → dart pub get → compile kernel |

## 根因

```
rhttp 0.10.0 位于 pub cache
  → cargokit 执行 run_build_tool.cmd
  → 脚本在 android/build/build/build_tool/ 下创建临时 Dart 项目
  → dart pub get → "Cannot operate on packages inside the cache"
  → build_tool_runner.dart 编译失败 → cargokit 跳过 Rust 编译
  → AAR 中没有 librhttp.so → APK 中没有 librhttp.so
```

## 修复

### 临时方案（当前使用）

从 2026-05-07 可用的 APK 中提取 librhttp.so，手动放入 `android/app/src/main/jniLibs/`：

```bash
unzip -o "working.apk" "lib/arm64-v8a/librhttp.so" -d "android/app/src/main/jniLibs/"
unzip -o "working.apk" "lib/armeabi-v7a/librhttp.so" -d "android/app/src/main/jniLibs/"
```

### 永久方案

1. 将 rhttp 移出 pub cache → 复制到 `local_packages/rhttp/`
2. pubspec.yaml 添加 dependency_overrides：
   ```yaml
   rhttp:
     path: ../local_packages/rhttp
   ```
3. **但仍需安装 cargo-ndk** 才能完整编译 Rust → 当前 rustc 1.84.1 不支持 cargo-ndk 最新版

### 验证

```bash
unzip -l app-arm64-v8a-release.apk | grep librhttp
# → lib/arm64-v8a/librhttp.so (3979752 bytes) ✅
```
