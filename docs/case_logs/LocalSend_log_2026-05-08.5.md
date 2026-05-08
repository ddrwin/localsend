---
name: 2026-05-08 下午 构建全记录#5 — 自动粘贴、PC同步、文档规范化
description: 下午 16:26~22:30 覆盖粘贴功能全平台实现、7次编译、2个bug修复、TLS排查、11个目录重命名、CHECK_BILL+BUG_INVENTORY 创建、全面自检
type: project
originSessionId: e8b0dde6-c272-4db9-9a4c-2bce7692d288
---

# 2026-05-08 下午 构建全记录 #5

## 会话概览

- **会话时长：** 16:26 ~ 22:30（约 6 小时）
- **Token 消耗：** 约 1 亿 2 千万
- **Build 次数：** 7 次（#5 ~ #11）
- **GitHub Release：** r3、r4
- **涉及文件变更：** ~20 个文件

---

## 完整时间线

| 时间 | 类型 | 内容 |
|------|------|------|
| 15:16 | Build #5 | Ninja 编译修复（$<CONFIG> 补丁），Release 引擎恢复 |
| 16:22 | Build #6 | 第一次 Android 构建（librhttp.so jniLibs 注入） |
| 16:22~16:50 | 代码 | 按钮样式调整（TextButton→ElevatedButton） |
| 16:50 | Build #7 | 按钮样式调整 + 群发修复 |
| 16:50~17:04 | 代码 | 按钮布局调整（取消→header）+ 详情页撑满 |
| 17:04 | Build #8 | 按钮布局 + 详情页撑满 |
| 17:04~17:28 | 代码 | 粘贴功能实现（方案A+B）+ `simulate_paste.dart` 创建 |
| 17:28 | Build #9 | **自动粘贴 + 历史面板粘贴（含 2 个 bug）** |
| 17:28~17:50 | 代码 | 提交 fb0861c、创建 r3 Release |
| 17:50~18:00 | 编译 | Windows build（`flutter_windows.dll.lib` 缺失，手动修复） |
| 18:00 | Build #10 | Windows 安装版 |
| 18:00~18:04 | 修复 | simulate_paste.dart 导入路径 + showSnackBar 类型错误 |
| 18:04 | Build #11 | Android 修复版，创建 r4 Release |
| 18:30 | 测试 | 用户测试发现 TLS handshake EOF |
| 18:30~18:40 | 排查 | TLS 排查：curl 能连、旧版也报错、引擎正确，排除编译问题 |
| 18:40~22:00 | 文档 | 目录重命名（11 个）、创建 CHECK_BILL.md、BUG_INVENTORY.md、更新 Ruler |
| 22:00~22:30 | 自检 | 全面对账，修复不一致，清理 git 状态 |

---

## 关键功能实现

### 1. 粘贴功能（方案A + 方案B）

**方案A — 收到消息自动粘贴：**
- `receive_controller.dart`：在 `Clipboard.setData()` 后调用 `simulatePaste()`
- 创建 `simulate_paste.dart`：封装 MethodChannel `localsend/paste`
- Windows：`flutter_window.cpp` 注册 MethodChannel，使用 SendInput API 模拟 Ctrl+V
  - `keybd_event` 不适合 → 改用 `SendInput`（4 个 INPUT：Ctrl down + V down + V up + Ctrl up）
  - `paste_channel_` 作为 `std::unique_ptr` 成员防止被 GC
- Android：`simulatePaste()` 返回 false → fallback 显示"已复制到剪贴板"

**方案B — 历史面板粘贴：**
- `receive_history_page.dart`：直接点击消息条目 → `Clipboard.setData()` + `simulatePaste()`
- 菜单重构：去掉"查看详情"，改为 粘贴内容 | 详细信息 | 删除

**局限（记录）：**
- Windows 端方案B有焦点限制：点击历史面板时焦点离开目标应用，Ctrl+V 粘到 LocalSend 自身而非目标窗口（B005）

### 2. 按钮布局统一

`message_input_dialog.dart`（共享代码，PC/Android 同时生效）：
- 取消：从底部挪到标题栏右上角 `×`
- 发送到所有设备：居中，ElevatedButton 蓝色样式
- 确认：最右边

### 3. 详情页文本区撑满

`receive_page.dart`：`SizedBox(height:100)` → `Expanded`，`MainAxisAlignment.center` → `start`（兼容 Expanded）

---

## Bug 清单（按编号）

### B002 — $<CONFIG> Ninja 空字符串（上午发现，下午修复）
- 见 BUG_INVENTORY.md 详细记录
- 修复验证：`flutter_windows.dll` 18MB（Release）✅

### B003 — simulate_paste.dart 导入路径错误
- 提交 fb0861c 中使用了不存在的 `checkPlatformIsWindows()`
- import 路径 `../platform_check.dart` 错误
- 修复版本：r4（#11）

### B004 — showSnackBar 类型错误
- `context.showSnackBar(SnackBar(content: ...))` → 接口期望 String
- 修复版本：r4（#11）

### B005 — 历史面板粘贴焦点限制
- 已知限制，Windows 无 API 跨窗口粘贴
- 当前方案：只复制到剪贴板

### B006 — TLS handshake EOF（运行时连接失败）
- **排查结论：** 不是编译问题，不是代码问题
- 证据链：
  1. 引擎正确（Release 18MB）→ 排除 B002
  2. curl -k（schannel）能正常连接 → 网络通
  3. 旧版 APK（#1 自动复制完成版）同样报错 → 排除今日代码引入
  4. 旧版 Windows 便携版同样报错 → 排除平台差异
- **根源推测：** rhttp 使用 rustls，curl 使用 schannel，rustls 与目标设备 TLS 协商失败
- **未解决。** 不确定是否目标设备（192.168.50.33）有变更

---

## Windows 编译坑点

### flutter_windows.dll.lib 缺失
- `flutter clean` 后 ephemeral 目录重新生成，但未包含 `.lib` 文件
- 手动复制：`C:\Flutter\flutter\bin\cache\artifacts\engine\windows-x64-release\flutter_windows.dll.lib` → `windows/flutter/ephemeral/`
- 已知复现条件：每次 `flutter clean` 后都需要手动补

---

## 文档体系重构

### 问题
用户反馈：
1. 目录命名分不清 PC 和 Android
2. 案例日志太简略
3. 没有统一的 Bug 追踪
4. 关机/结束会话前没有对账清单

### 解决

| 新增文档 | 作用 |
|---------|------|
| `docs/RELEASE_CHECKLIST.md` | 发布后逐条执行（6 个章节） |
| `docs/CHECK_BILL.md` | 关机前对账（7 个章节，含代码/构建/Release/案例日志/Bug/规则/记忆） |
| `docs/BUG_INVENTORY.md` | 所有 Bug 唯一编号 + 详细记录（B001~B006） |

### 目录重命名（11 个）

旧格式：`LocalSend_YYYYMMDD_HHMMSS_描述`
新格式：`LocalSend_YYYYMMDD_HHMMSS_平台_类型_描述`

- 平台：`PC` / `Android` / `PC便携版+AndroidAPK`
- PC 类型：`便携版`（散装） / `安装版`（Inno Setup）
- Android 类型：`APK`

### Ruler 精简
WORKFLOW_RULES.md 顶部加核心规则：
> **每次发布时，执行 RELEASE_CHECKLIST.md，逐条打勾。**

---

## 自检流程

22:00~22:30 执行了 Check Bill 对账：

1. 物理目录 vs BUILD_LOG.md → 一致 ✅
2. 案例日志三处同步 → 全部一致 ✅
3. MEMORY.md 索引 → 完整 ✅
4. D 盘备份 → 发现 BUILD_LOG.md 和 GITHUB_LOG.md 不一致 → 已修复
5. GitHub Releases → r1~r4 全部有效 ✅
6. git 状态 → 有未跟踪文件（temp、installer）→ 清理 + 更新 .gitignore
7. .gitignore 修复：移除危险 `C:*` 模式、添加 `installer/`

---

## 遗留问题

| 问题 | 级别 | 状态 |
|------|------|------|
| B006 TLS handshake EOF | 🔴 阻塞 | 排查中，非编译问题，目标设备相关 |
| B005 粘贴焦点限制 | ⚠️ 低 | 已知限制，不改 |
| cargo-ndk / rustc 太旧 | ⚠️ 中 | 阻塞 Android Rust 原生编译，jniLibs 临时方案 |
| flutter clean 后需手动补 .lib | ⚠️ 低 | Windows 编译流程已知坑 |
