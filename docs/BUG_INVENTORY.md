# LocalSend Bug Inventory（Bug 清单）

> 按日期倒序排列。每个 bug 有唯一编号，方便跨文档引用。
> 状态：`✅ 已修` / `🔴 未修` / `⚠️ 已知限制` / `🔍 排查中`

---

## 2026-05-08

### B006 — TLS handshake EOF（运行时连接失败）

| 字段 | 内容 |
|------|------|
| **状态** | 🔍 排查中 |
| **发现时间** | 2026-05-08 18:30 |
| **现象** | Windows 端连接 Android 设备时：`tls handshake eof`，`hyper_util::client::legacy::Error(Connect, Custom { kind: UnexpectedEof })` |
| **复现步骤** | 任何 Windows 构建（包括旧版）向 192.168.50.33:53317 发文件 |
| **排查进展** | ① 引擎确认 Release（排除 $<CONFIG> bug）→ ② curl（schannel）能正常连接 → ③ 旧版 APK/便携版同样报错 → ④ 确认非编译问题 |
| **根因** | 待定。rhttp 使用 rustls，curl 使用 schannel，怀疑目标设备 TLS 配置或 rustls 兼容性 |
| **关联** | 与 B002（$<CONFIG> TLS 异常）不同。B002 是编译问题（Debug 引擎），B006 是运行时 TLS 协商 |
| **下次排查** | 检查 192.168.50.33 设备上的 LocalSend 版本；抓包看 TLS 握手详情 |

---

### B005 — 历史面板粘贴焦点限制

| 字段 | 内容 |
|------|------|
| **状态** | ⚠️ 已知限制 |
| **发现时间** | 2026-05-08 17:28（功能实现时） |
| **现象** | 点击历史面板时焦点离开目标应用，SendInput(Ctrl+V) 粘到 LocalSend 而非目标窗口 |
| **根因** | Windows 安全限制：没有 API 能"记住之前光标位置并往那里粘贴" |
| **当前方案** | 只复制到剪贴板，弹出"已复制到剪贴板"，让用户手动 Ctrl+V |
| **备注** | Android 端无此问题（无模拟粘贴，只复制到剪贴板） |

---

### B004 — showSnackBar 类型错误

| 字段 | 内容 |
|------|------|
| **状态** | ✅ 已修 |
| **发现时间** | 2026-05-08 17:28（代码审查时发现） |
| **现象** | `context.showSnackBar(SnackBar(content: Text(...)))` 传了 SnackBar widget，但接口期望 String |
| **根因** | `showSnackBar` 扩展方法接受 String 而非 SnackBar 对象 |
| **修复** | `context.showSnackBar(t.general.copiedToClipboard)` |
| **修复版本** | v1.17.1-android-r4（#11） |
| **备注** | 此 bug 导致 r3 在 Android 上粘贴功能异常 |

---

### B003 — simulate_paste.dart 导入路径错误

| 字段 | 内容 |
|------|------|
| **状态** | ✅ 已修 |
| **发现时间** | 2026-05-08 17:28（编译时发现） |
| **现象** | 引用了不存在的 `checkPlatformIsWindows()`，import 路径为 `../platform_check.dart` |
| **根因** | 初始实现时写错了导入路径和函数名 |
| **修复** | `checkPlatform([TargetPlatform.windows])` + 正确 import |
| **修复版本** | v1.17.1-android-r4（#11） |
| **备注** | 此 bug 导致 r3 在 Android 上 simulatePaste 可能 crash |

---

### B002 — `$<CONFIG>` 在 Ninja 下为空字符串 → Debug 引擎

| 字段 | 内容 |
|------|------|
| **状态** | ✅ 已修 |
| **发现时间** | 2026-05-08 12:19 |
| **现象** | `flutter build windows --release` 产物为 Debug 引擎（45MB），TLS handshake EOF |
| **根因** | `CMakeLists.txt:100` 用 `$<CONFIG>` 确定构建模式。Ninja 单配置生成器下 `$<CONFIG>` 求值为空 → `tool_backend.bat` 收到空参数 → 组装 debug 引擎 |
| **修复** | `build_windows.dart` 中 `_runCmakeGeneration` 对 Ninja 添加 `-DCMAKE_BUILD_TYPE=Release` |
| **修复版本** | #5（Ninja 编译修复） |
| **验证方法** | `flutter_windows.dll` 大小：18MB = Release ✅ / 45MB = Debug ❌ |
| **上游 issue** | https://github.com/localsend/localsend/issues/3028 |
| **补丁文件** | `docs/patches/flutter_build_windows_ninja_cmake_type.patch` |

---

### B001 — librhttp.so 缺失（cargokit pub cache bug）

| 字段 | 内容 |
|------|------|
| **状态** | ✅ 已修（临时） |
| **发现时间** | 2026-05-08 16:22 |
| **现象** | APK 缺少 `librhttp.so`（3.8MB），APK 仅 15MB 应为 18MB+ |
| **根因** | `rhttp-0.10.0` 在 pub cache 中 → cargokit 无法 `dart pub get` → 跳过 Rust 编译 → AAR 无 .so |
| **修复（临时）** | 从旧 APK 提取 librhttp.so 注入 `jniLibs/` |
| **修复（永久）** | `dependency_overrides` 指向 `local_packages/rhttp/`（脱离 pub cache），但仍需 cargo-ndk |
| **修复版本** | #6（Android 群发修复版） |
| **阻塞项** | rustc 1.84.1 太旧，不支持最新 cargo-ndk |
| **备注** | 因为 Windows 端不涉及 Android 交叉编译，无此问题 |
