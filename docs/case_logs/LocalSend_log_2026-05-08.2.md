---
name: 2026-05-08 Windows 编译修复全记录（上午）
description: 从 VS 2022 被删到 Ninja + MSVC 2026 跑通，完整时间线、每个尝试的根因和结论
type: project
originSessionId: 2883715d-736e-487f-b4b3-29c62af5db1e
---

# 2026-05-08 Windows 编译环境修复全记录

> 创建时间：2026-05-08 11:58
> 涉及版本：Flutter 3.24.5 / VS 2026 BuildTools 18.5.1 / CMake 3.31.6 / Ninja

---

## 前情回顾

昨日（5月7日）的构建环境是 **VS 2022 BuildTools**，已正常安装并注册到系统中：
- VS 2022 文件位于 `C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools`
- vswhere COM API 状态缓存正常（`%ProgramData%\Microsoft\VisualStudio\Setup` 有实例数据）
- CMake 的 VS 17 2022 生成器能通过 COM API 找到 VS → 编译通过（耗时约 110s）
- 源码已从 E 盘中文路径迁移到 C 盘英文路径，解决了中文编码 mojibake 问题
- 自动复制改造和安卓按钮互换已完成

今日开始前的遗留问题：
- Windows 编译环境还在用 VS 2022，但用户想清理 C 盘空间
- 用户希望把所有构建产物统一归到 E 盘
- 需要创建安装包（Inno Setup）
- 需要更新版本号

---

## 完整时间线

### 08:00 — VS 2022 删除，灾难开始

用户同意清理方案（"123照搬"）后执行了以下操作：
1. 删除 `C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools`（整个目录，约 4GB）
2. 删除 VS 包缓存（`C:\ProgramData\Microsoft\VisualStudio\Packages`，约 30GB）
3. 移动 `C:\localsend_app_build` → `E:\CodeBase\localsend\localsend_app_build\`

**结果：flutter build windows --release 直接崩溃。** Flutter 的 `visual_studio.dart` 调用 vswhere → vswhere COM API 返回空 → 找不到 VS。

---

### 08:00–08:30 — 修复尝试 #1：Flutter 层绕过 vswhere

**问题定位：** Flutter 的 VS 检测代码完全依赖 vswhere COM API，COM API 读取的状态缓存已被 VS 卸载器清空。

**方案：** 在 `visual_studio.dart` 的 `_bestVisualStudioDetails` 方法中，优先检查环境变量 `VS_INSTALL_PATH`，如果存在且路径有效，直接返回 VS 信息，跳过 vswhere。

**修改：**
```dart
final String? envVSPath = _platform.environment['VS_INSTALL_PATH']?.trim();
if (envVSPath != null && _fileSystem.directory(envVSPath).existsSync()) {
  return VswhereDetails(...);
}
```

**结果：** Flutter 层面通过了，能正确获取 cmakePath 和 cmakeGenerator。但 CMake 的 VS 17 2022 生成器做自己的检测 → 仍然找不到 VS。

**结论：** Flutter 检测 VS 和 CMake 检测 VS 是两条独立的链路。只修 Flutter 不够。

---

### 08:30–09:00 — 修复尝试 #2：目录交接 + 注册表伪装

**思路：** CMake 的 VS 17 2022 生成器通过注册表和 COM API 找 VS。如果能"骗"过 CMake 让它以为 VS 2022 还在，就能工作。

**操作：**
1. 创建目录交接点：`2022\BuildTools → 18\BuildTools`，让 VS 2026 的文件可以通过 2022 路径访问
2. 注册表 `f230a47d` 的 `installationPath` 指向 `2022\BuildTools`，`installationVersion` 设为 `17.14.37216.2`
3. SxS 键 `HKLM\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\SxS\VS17` 指向 `18\BuildTools`
4. 设置 `VS170COMNTOOLS` 环境变量指向 `18\BuildTools\Common7\Tools\`

**结果：** CMake 3.31.6 和 CMake 4.2.3（VS 捆绑版）都报同样的错误：`could not find any instance of Visual Studio`。

**根因分析：** CMake 从 3.28+ 开始，VS 生成器的检测逻辑被重写过，**主要依赖 vswhere COM API**，SxS 注册表和 `VS170COMNTOOLS` 这些传统的 fallback 机制被移除或弱化。vswhere 返回空 → CMake 直接失败，不再 fallback。

---

### 09:00–09:30 — 修复尝试 #3：CMAKE_GENERATOR_INSTANCE

**思路：** CMake 支持 `CMAKE_GENERATOR_INSTANCE` 变量直接指定 VS 实例路径。

**尝试：**
1. `-DCMAKE_GENERATOR_INSTANCE="18\BuildTools"` → `no 'version=' field was given`
2. `-DCMAKE_GENERATOR_INSTANCE="18\BuildTools;version=18.5.1"` → `contains invalid field`
3. 用短路径名（无空格）→ 一样错误
4. 测试 CMake 3.31.6 和 VS 捆绑的 4.2.3 → 行为一致

**根因分析：** CMake 需要 COM API 来验证 VS 实例。`CMAKE_GENERATOR_INSTANCE` 的值在 CMake 内部会用 `;` 分割解析，但新版本要求 path 不包含 `version=X.Y.Z` 后缀——或者根本不再支持 path-only 模式。

**结论：** 此路不通。CMake 强制依赖 COM API。

---

### 09:30–10:00 — 修复尝试 #4：vswhere 状态缓存手动重建

**思路：** vswhere 读取 `%ProgramData%\Microsoft\VisualStudio\Setup\x64\` 下的实例文件。如果能重建这个缓存，vswhere 就能找到 VS。

**检查：**
- 目录存在但只有 `Microsoft.VisualStudio.Setup.Configuration.Native.dll` 文件
- 没有 `Instances\` 或 `State\` 子目录
- 尝试了 `vs_installer.exe modify --help` → 无输出（可能不支持）

**结果：** 放弃。不知状态文件的 JSON schema 而且 vs_installer 无法注册。

---

### 10:00–10:30 — 修复尝试 #5：Ninja 生成器（第一次尝试）

**思路：** 不用 VS 生成器，改用 Ninja 生成器。Ninja 不需要找 VS——它直接用 PATH 里的编译器。

**操作：**
1. 先调用 vcvars64.bat（设置 PATH、INCLUDE、LIB 等环境变量）
2. 用 CMake + Ninja 生成器
3. Ninja 不认 `-A` 参数，不认 `target INSTALL`（需要小写 `install`）

**修改了 build_windows.dart：**
- 添加了 `CMAKE_GENERATOR_INSTANCE`（这是之前改的）
- 重新设计了 `_runCmakeGeneration` 和 `_runBuild`

**结果：** CMake Generation 成功！但 cmake --build 失败：
- `--target INSTALL` → Ninja 只有 `install`（小写）
- `-A x64` → Ninja 不认识（需要条件跳过）

**结论：** 思路正确，但 Flutter 的 build 脚本对 Ninja 不友好，需要更多适配。

---

### 10:30–11:00 — 修复尝试 #6：更多 VS 生成器暴力尝试

回头看 VS 生成器：
- 尝试了所有 CMake 版本（VS 捆绑的 4.2.3 + 独立的 3.31.6）
- 尝试了所有环境变量组合（VS170COMNTOOLS, VSINSTALLDIR, VisualStudioVersion）
- 确认 CMake 3.31+ 彻底移除了对 VS170COMNTOOLS 的 fallback
- 整个 VS 生成器路径彻底堵死

---

### 11:00–11:10 — 修复尝试 #7：Ninja 生成器（第二次尝试，成功）

**关键决定：** 既然没有别的路可走，花时间把 Ninja 适配做完整。

**完整修改清单：**

`visual_studio.dart`:
- `cmakeGenerator`：当 `FLUTTER_USE_NINJA=true` 时返回 `"Ninja"`
- `cmakePath`：当 `FLUTTER_CMAKE_PATH` 设置时，返回独立 CMake 3.31.6 的路径（而非 VS 捆绑版）

`build_windows.dart`:
- `_runCmakeGeneration`：当 generator 为 `"Ninja"` 时，跳过 `-A` 参数
- `_runBuild`：接收 generator 参数，Ninja 时用 `--target install`（小写），否则用 `INSTALL`（大写）

`build_windows.bat`:
- 添加 `FLUTTER_USE_NINJA=true`
- 添加 `FLUTTER_CMAKE_PATH` 指向独立 CMake 3.31.6
- 添加 Ninja 到 PATH
- 保留 `VS_INSTALL_PATH`、`VS170COMNTOOLS` 等变量

**注意：** Flutter 工具是 AOT 编译的，改了 `.dart` 文件后必须删掉 `bin/cache/flutter_tools.snapshot` 和 `.stamp`，让 Flutter 下次启动时重新编译工具。这一步没做的话，改的代码不会生效。

---

### 11:10–11:30 — 踩坑 #8：flutter_windows.dll.lib 未声明

CMake Generation 成功了。Ninja 也跑了。但立刻报错：
```
ninja: error: '.../flutter_windows.dll.lib', missing and no known rule to make it
```

**根因：** Flutter 的 `windows/flutter/CMakeLists.txt` 中 `flutter_assemble` 的自定义命令：
```cmake
add_custom_command(
  OUTPUT ${FLUTTER_LIBRARY} ${FLUTTER_LIBRARY_HEADERS} ...  # 注意：没有 .lib!
  COMMAND ... tool_backend.bat ...
)
```

`OUTPUT` 列表中声明了 `flutter_windows.dll`（FLUTTER_LIBRARY），但 **没有声明 `flutter_windows.dll.lib`**。而 `flutter` INTERFACE 库通过 `target_link_libraries(flutter INTERFACE "${FLUTTER_LIBRARY}.lib")` 引用了 `.lib`。

- **MSBuild（VS 生成器）：** 宽容处理，不检查 OUTPUT 完整性，`flutter_assemble` 运行后 .lib 自然存在
- **Ninja：** 严格要求 INPUT→OUTPUT 声明，不知道 .lib 是怎么生成的 → 报错

**临时修复：** 从引擎缓存手动复制 .lib 文件到 ephemeral 目录。

**根本修复建议：** 在 Flutter 的 CMakeLists.txt 中把 `.lib` 也加入 `OUTPUT` 列表。

---

### 11:30–11:35 — 踩坑 #9：MSVC 2026 拒绝 `/wd"4100"`

复制完 .lib 重新编译，Ninja 跑了但所有 `.cpp` 都编译失败：
```
cl: error D8021: invalid numeric argument '/wd"4100"'
```

**根因：** MSVC 2026（cl.exe 19.50）比 MSVC 2022（cl.exe 19.3x）更严格。`/wd"4100"` 带引号的形式被拒绝，只接受 `/wd4100`（无引号）。

**修复位置：** `windows/CMakeLists.txt` 第 42 行：
```cmake
# 改前：
target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
# 改后：
target_compile_options(${TARGET} PRIVATE /W4 /WX /wd4100)
```

**教训：** 换了 MSVC 大版本后，编译器 flag 的兼容性需要验证。MSVC 2022 没问题的写法在 MSVC 2026 可能报错。

---

### 11:35 — 编译成功！

```
Building Windows application...  26.7s
√ Built build\windows\x64\runner\Release
```

比 VS 生成器时代的 110s 快了近 **4 倍**。原因是 Ninja 比 MSBuild 轻量很多，而且单配置生成器没有 Debug/Release 目录翻倍的问题。

---

### 11:35–12:00 — 收尾工作

1. **版本号更新：** pubspec.yaml `1.17.0+58` → `1.17.1+59`
2. **安装包制作：** Inno Setup 编译成功，输出 `LocalSend-1.17.1-windows-x64.exe`（35MB）
3. **安装脚本更新：** `BuildDir` 路径从 `runner\Release` 改为 `runner`（Ninja 是单配置生成器，没有 Release 子目录）

---

## 关键架构关系图

```
Flutter 检测 VS 链路（两条独立路径）

路径 A：Flutter 内部检测（用于获取 cmakePath 和 cmakeGenerator）
  visual_studio.dart → _bestVisualStudioDetails
    → [patch] 先检查 VS_INSTALL_PATH 环境变量 ← 绕过 vswhere
    → fallback vswhere COM API

路径 B：CMake 检测 VS（用于实际编译）
  build_windows.dart → cmake -G "Visual Studio 17 2022" -A x64
    → CMake 内部检测（3.28+ 只用 COM API，不再 fallback 注册表/env）
    → [patch] 改为 Ninja 生成器，跳过 COM API 依赖

Ninja + vcvars 模式：
  vcvars64.bat → 设置 PATH(cl.exe)、INCLUDE、LIB
  cmake -G Ninja → 用 PATH 里的 cl.exe，不需要找 VS
  ninja --target install → 编译 + 安装到输出目录
```

## 问题分类总结

| 问题 | 根因 | 修复方式 | 时间成本 |
|------|------|----------|----------|
| VS 被删后找不到 | CMake 3.28+ 硬依赖 vswhere COM API | 改用 Ninja 生成器 | ~2h |
| Flutter 工具改代码不生效 | AOT snapshot 缓存 | 删 stamp 强制重编译 | ~10min |
| Ninja 缺 .lib 声明 | Flutter CMakeLists.txt OUTPUT 列表不全 | 手动复制 / 需修 upstream | ~20min |
| MSVC 2026 不认 `/wd"4100"` | 编译器大版本升级，flag 语法变严格 | 去引号 `/wd4100` | ~5min |
| 安装包路径不对 | Ninja 是单配置生成器，无 Release 子目录 | BuildDir 改为 runner | ~5min |

## 教训总结

1. **CMake 3.28+ VS 检测只走 COM API** — 注册表、环境变量、SxS 键这些传统方法全部失效。VS 被卸载=CMake 永远找不到。
2. **Ninja 比 MSBuild 快但更严格** — OUTPUT 声明不能缺，target 名区分大小写。Flutter 对 Ninja 的适配有残缺。
3. **MSVC 大版本升级有兼容风险** — 编译器 flag、语言特性开关都可能变。MSVC 2022→2026 这个跳级尤其危险。
4. **两条检测链路要分开理解** — Flutter 检测 VS（拿到 cmake 路径和生成器名）和 CMake 检测 VS（实际编译）是独立的。修一条不影响另一条。
5. **Dart 修改→AOT 缓存失效** — 改了 Flutter 工具链的 .dart 文件后必须删 snapshot，否则改了等于没改。

## 用户确认的架构总结

用户复盘后确认的编译环境整体关系：

```
Flutter 检测 VS 的流程：
  用户删除 VS 2022 → COM API 状态缓存清空 → vswhere 返回空
  → 两种方案：
    方案 A（VS 生成器）：COM API 找不到 → 失败（CMake 3.28+ 不再 fallback 注册表/env）
    方案 B（Ninja 生成器）：不需要找 VS，直接调 vcvars64.bat 拿编译器 → 跑通
  → Ninja 生成器调用的仍是 VS 2026 BuildTools 的 MSVC 编译器（cl.exe 19.50）
  → 核心区别：VS 生成器需要"注册表登记"找到 VS，Ninja 直接从 PATH 拿工具

两条独立的 VS 检测链路：
  链路 1：Flutter 内部检测（visual_studio.dart）→ 用于获取 cmake 路径和生成器名
  链路 2：CMake 检测（cmake --build）→ 实际编译
  修链路 1 不影响链路 2，反之亦然。这是最初绕弯路的原因。
```
