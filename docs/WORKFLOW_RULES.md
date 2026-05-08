# LocalSend 项目协作规则

> 最后更新：2026-05-08
>
> ## ⚡ 核心规则（只需记这两条）
>
> **1. 每次发布时** → 执行 [`docs/RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md)，逐条打勾。
> **2. 每次结束会话前** → 执行 [`docs/CHECK_BILL.md`](CHECK_BILL.md)，对账关机。
>
> **Bug 追踪** → 见 [`docs/BUG_INVENTORY.md`](BUG_INVENTORY.md)，每个 bug 唯一编号 B001~B006。
>
> --
>
> 本文件三个位置同步存放：
> 1. **工作目录/公共文档** `E:\CodeBase\localsend\docs\WORKFLOW_RULES.md`
> 2. **记忆目录** `C:\Users\Administrator\.claude\projects\D----\memory\`
> 3. **项目备份** `D:\同步文件夹\软件\3 - AI 生产力\5. 项目Projects\LocalSend v1.17.0 自动复制改造\`

---

## 一、构建产物归档规则

### 目录结构

```
E:\CodeBase\
├── build_outputs\              ← 所有构建产物根目录
│   ├── BUILD_LOG.md            ← 构建日志（每个新目录追加一条）
│   ├── GITHUB_LOG.md           ← GitHub 提交记录
│   └── LocalSend\              ← LocalSend 项目构建产物
│       ├── LocalSend_20260507_201200_自动复制完成/
│       ├── LocalSend_20260508_085100_VS2022便携版/
│       └── ...
└── localsend\                  ← 项目源代码目录（git 仓库）
    ├── app/
    ├── docs/                   ← 公共文档
    │   ├── BUILD_SYSTEM.md
    │   ├── WORKFLOW_RULES.md
    │   ├── case_logs/
    │   └── patches/
    └── ...
```

### 目录命名规范

```
LocalSend_<YYYYMMDD_HHMMSS>_<平台>_<类型>_<描述>
```

- 时间戳在前，按字母排序即按时间排序
- **平台**标注：`PC`（Windows）/ `Android` / `PC便携版+AndroidAPK`（混合）
- **类型**标注：
  - PC：`便携版`（散装 exe+dll）/ `安装版`（Inno Setup 安装包）
  - Android：`APK`（安卓安装包）
- 描述使用中文，简短一句话概括本次构建特点

示例：
```
LocalSend_20260508_180000_PC安装版_自动粘贴布局同步
LocalSend_20260508_181000_AndroidAPK_修复导入路径SnackBar
LocalSend_20260508_162200_AndroidAPK_群发修复
LocalSend_20260508_151600_PC安装版_Ninja编译修复
LocalSend_20260507_201200_PC便携版+AndroidAPK_自动复制完成
```

### 每次新增构建产物的步骤

详见 [`docs/RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md)，按章节逐条执行即可。不再在此重复列出。

> **改名同步规则：** 如果重命名了物理目录，必须在 BUILD_LOG.md 的「目录结构」和对应章节标题中同步更新，否则日志与目录不匹配。

---

## 二、GitHub 管理规则

- 源代码（.dart、.yaml、.bat、.md 等）推送到 GitHub
- 构建产物（.exe、.apk、便携版目录）不上传 GitHub，只存本地 `build_outputs\`
- **每次有源码变更时，必须 push 到 GitHub**（除非明确告知无需推送）
- 每次推送后更新 `GITHUB_LOG.md`
- 如需在 GitHub 提供下载，创建 GitHub Release 并上传附件

### 提交信息规范

commit message 第一行用英文简写类型：
```
feat: ...    ← 新功能
fix: ...     ← 修 bug
docs: ...    ← 文档
chore: ...   ← 杂项（版本号、构建配置等）
```

---

## 三、文档同步规则

每次更新后，三个位置都要同步：

| 位置 | 用途 | 谁读 |
|------|------|------|
| 记忆目录 `memory/` | 会话间持久化，下次启动自动加载 | Claude |
| 公共文档 `docs/` | 工作目录，可追溯版本历史 | 用户 + Claude |
| 项目备份 `D:\...\项目Projects\` | 用户日常查看和复盘 | 用户 |

---

## 四、知识保存规则（案例日志）

重要决策、坑点记录、工作流变更必须记录案例日志。

### 命名规范

```
LocalSend_log_<YYYY-MM-DD>.<序号>.md
```

- 项目前缀 `LocalSend_log_`，与构建产物 `LocalSend_` 统一
- 同一天多份用 `.1` `.2` `.3` 区分
- 示例：`LocalSend_log_2026-05-08.1.md`

### 触发时机

**每次有批量产出物时自动写入。** 包括但不限于：
- 编译调试完成（环境搭建、工具链修复）
- Bug 修复完成
- 新功能实现完成
- 构建产物产生（安装包/APK/便携版）

简而言之：每次你提交产出物时，同步写一份案例日志。

### 内容要求

- 时间戳
- 遇到的问题和根因
- 尝试过的方案和结论
- 最终修复方式
- 工作流中遇到的障碍
- 架构关系图（如有必要）

既是快照（记录过程），也是复盘（总结经验）。

### 存放位置（三处同步）

| 位置 | 路径 | 说明 |
|------|------|------|
| 案例日志主目录 | `D:\同步文件夹\软件\3 - AI 生产力\0. 工程哲学\案例日志\` | 用户日常查阅、复盘 |
| 记忆目录 | `C:\Users\Administrator\.claude\projects\D----\memory\case_logs\` | Claude 跨会话读取 |
| 公共文档 | `docs/case_logs/` | git 跟踪，可回溯版本 |

---

## 五、构建环境现状

| 组件 | 版本 | 路径 |
|------|------|------|
| Flutter | 3.24.5 | `C:\flutter\flutter\` |
| MSVC | 2026 BuildTools (cl.exe 19.50) | `C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\` |
| CMake | 3.31.6（独立版） | `C:\Program Files\CMake\cmake-3.31.6-windows-x86_64\bin\cmake.exe` |
| Ninja | VS 捆绑版 | `C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja\` |
| 生成器 | Ninja（单配置） | 通过 `build_windows.bat` 调用 |

### 已知坑点

**`$<CONFIG>` 在 Ninja 下为空字符串**

- CMakeLists.txt:100 用 `$<CONFIG>` 确定构建模式
- Ninja 单配置生成器下求值为空 → `tool_backend.bat` 收到空参数 → 组装 debug 引擎（45MB）
- 修复：在 `_runCmakeGeneration` 中对 Ninja 添加 `-DCMAKE_BUILD_TYPE=Release`
- 验证：检查 `flutter_windows.dll` 大小应为 18MB（release）
- 补丁：`docs/patches/flutter_build_windows_ninja_cmake_type.patch`

**Flutter SDK 修改后需清缓存**

修改 `C:\flutter\flutter\packages\flutter_tools\lib\src\windows\` 下的 .dart 文件后：
```bash
rm -f bin/cache/flutter_tools.snapshot bin/cache/flutter_tools.stamp
```
否则改动不会生效。

---

## 六、项目版本号

当前版本：`v1.17.1+59`（位于 `app/pubspec.yaml`）

版本更新时同步更新：
- `pubspec.yaml` 中的 `version:` 字段
- Inno Setup 脚本中的版本号
- 构建产物的 README.md

---

## 八、编码问题 — 终端中文乱码

Flutter 构建脚本（.bat）在 bash/Cygwin 环境中执行时，cmd.exe 输出的中文字符会变成乱码（mojibake）。

**根因：** bash 使用 UTF-8，cmd.exe 使用系统 ANSI 代码页（中文 Windows 为 CP936/GBK）。

**修复：** 所有 .bat 文件首行添加 `chcp 65001 > nul`，将控制台切换到 UTF-8 代码页。

已在以下文件添加：
- `build_windows.bat`
- `build_android.bat`

---

## 九、Claude 语言要求

Claude 在项目中的所有输出必须使用 **中文**：
- 思考过程、状态更新、问题诊断用中文
- 代码注释、提交说明用中文
- 构建产物 README.md 用中文

**例外：** commit message 第一行保留英文类型前缀（feat:/fix:/docs:/chore:），这是 Git 惯例，不变。

---

## 十、已知 Android 构建坑点

### rhttp/cargokit pub cache 问题

**现象：** `flutter build apk` 构建的 APK 缺少 `librhttp.so`（3.8MB），APK 仅 15MB 应为 18MB+。

**根因：** `rhttp-0.10.0` 位于 `Pub\Cache\hosted\pub.dev\` 中。cargokit 的 `run_build_tool.cmd` 需要在临时目录执行 `dart pub get`，但 `pub get` 不允许在 pub cache 内操作 → cargokit 无法编译 Rust 代码 → AAR 中没有 .so → APK 中没有 .so。

**修复（临时）：**
```bash
# 从可用的旧 APK 提取 librhttp.so 到 jniLibs
unzip -o "旧APK.apk" "lib/arm64-v8a/librhttp.so" -d "android/app/src/main/jniLibs/"
unzip -o "旧APK.apk" "lib/armeabi-v7a/librhttp.so" -d "android/app/src/main/jniLibs/"
```

**修复（永久）：**
1. rhttp 已复制到 `local_packages/rhttp/`（脱离 pub cache）
2. pubspec.yaml 使用 `dependency_overrides` 指向本地路径
3. 但仍需安装 cargo-ndk（当前 rustc 1.84.1 不支持）才能完整编译

---

## 七、自动复制改造要求

- PC 端：发送文件时不弹窗（直接走确认流程）
- Android 端：发送面板正常消失
- 3 状态选择器：off / favorites / on（互斥逻辑在 receive_tab.dart）

---

## 十一、粘贴功能已知问题（2026-05-08）

### Windows 历史面板粘贴 — 焦点限制

**问题：** 点击 LocalSend 历史面板时，焦点从浏览器/其他应用移到 LocalSend，此时 SendInput 模拟 Ctrl+V 会粘到 LocalSend 自身，而非目标应用。

**限制：** Windows 没有 API 可以"记住之前光标位置并往那里粘贴"。这是操作系统的安全限制。

**当前方案：** 点击历史面板只复制到剪贴板，不模拟粘贴，弹出"已复制到剪贴板"提示，由用户手动 Ctrl+V。

### TLS handshake EOF（2026-05-08 发现）

**现象：** Windows 端连接 Android 设备时报错：
```
tls handshake eof
hyper_util::client::legacy::Error(Connect, Custom { kind: UnexpectedEof })
```

**排查结论：** 排除了编译问题（引擎 Release 正确），旧版 APK/便携版同样报错。curl（schannel）能正常连接。可能与目标设备 TLS 配置或 rustls 兼容性有关，待进一步排查。
