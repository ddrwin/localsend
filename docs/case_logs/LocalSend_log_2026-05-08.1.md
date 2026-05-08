---
name: 2026-05-08 项目复盘日志
description: 复盘昨天（5月7日）三个构建/开发问题的根因分析和教训
type: project
originSessionId: 2883715d-736e-487f-b4b3-29c62af5db1e
---
# 2026-05-08 项目复盘日志

## 问题一：编译未使用最新版本

### 现象
从下午到晚上一直在 build，所有 Dart 代码改动都没有生效。app.so 始终是旧版本。用户的实际体验是"改了跟没改一样"。

### 根因
Flutter 的 cmake 构建流程中，`flutter_assemble` 负责生成 `app.so`。正常情况下流程是：
1. `cmake --build` → `flutter_assemble` → 生成新 `app.so`
2. `app.so` 被自动安装到 `runner/Release/data/` 目录

但实际排查发现：
- `cmake --build` 虽然运行成功，但 `flutter_assemble` 悄悄失败了（因为中文路径 mojibake）
- 旧的 `app.so` 仍留在 `runner/Release/data/` 目录中
- 手动复制 `app.so` 时，复制的是旧文件（`cmake --build` 输出目录里的 app.so 没有被更新）
- 最终用户给出的 exe 里打包的还是旧版 `app.so`

### 教训
- 每次 cmake 构建后，**必须验证 app.so 的时间戳和内容**，不能只看 cmake 退出码
- 如果 `flutter_assemble` 报错，cmake --build 本身仍可能返回 exit code 0（子进程失败不传播）
- **验证命令**：`grep -c "你的新函数名" build/windows/runner/Release/data/app.so`，返回 0 说明没生效
- 构建后应检查 `runner/Release/data/app.so` 的修改时间是否更新

### 预防
- 构建脚本中增加 app.so 内容校验步骤
- 每次 `cmake --build` 后检查 `flutter_assemble` 日志（而不是只看 cmake 自身的输出）
- 如果改了 Dart 代码但 app.so 没变，立刻停止排查构建链路

---

## 问题二：E 盘中文路径导致 generated_config.cmake 编码损坏

### 现象
`generated_config.cmake` 中 `PROJECT_DIR` 指向 `E:\下载\localsend-1.17.0\app`。当 `flutter_assemble` 通过 cmake 环境变量传递这个路径时，中文"下载"两个字被编码成 UTF-8 双重编码（著名的"锟斤拷" mojibake），导致 `flutter_assemble` 找不到 `app.dill`。

### 根因
原始的 LocalSend 源代码被解压在 `E:\下载\localsend-1.17.0\app`（E 盘，"下载"是中文目录名）。
- `flutter pub get` 生成 `generated_config.cmake` 时，`PROJECT_DIR` 写入了中文路径
- cmake 在传递路径给 `flutter_assemble` 时，中文字符被二次编码
- `flutter_assemble` 收到乱码路径 `E:\锟斤拷锟斤拷\...\app.dill`，无法找到文件
- 表现为 `flutter_assemble` 崩溃，但 `cmake --build` 继续执行并返回成功

后续将代码同步到了 `C:\localsend\app`（纯英文路径），但：
- 每次 `flutter pub get` 重新生成 `generated_config.cmake` 时，路径又变回 E 盘中文
- 修复方法：手动修改 `generated_config.cmake` 中所有路径为 C 盘英文路径

### 根因链
```
用户把源码解压到 E:\下载\ (中文路径)
  → flutter pub get 写入中文路径到 generated_config.cmake
    → cmake 传递路径时 UTF-8 二次编码
      → flutter_assemble 收到乱码路径 → 崩溃 → app.so 不更新
```

### 为什么一开始没发现
- 第一次设置时，不清楚源码放在了 E 盘中文路径
- 记忆文件中没有记录源码的原始位置和后续的同步步骤
- 没有在 CLAUDE.md 或本地文档中记录"源码位置→构建产物"的依赖关系

### 预防
- **源码必须放在纯英文路径下**，这是 Flutter 项目的硬性要求
- 修改 `generated_config.cmake` 后，重新执行 `flutter pub get` 会覆盖此文件
- 若需彻底解决，应将项目移到纯英文路径后重新 `flutter pub get` 一次，确保 generated_config.cmake 干净
- 在本地文档中明确记录"源码路径"这一关键前提条件

---

## 问题三：安卓端按钮互换成 PC 端

### 现象
用户要求修改**安卓端**的文本/文件按钮位置，但我改成了 **PC 端（Desktop 分支）** 的按钮顺序。

### 根因
1. **未确认用户的具体指向** — 用户说要改按钮位置，我直接改了代码，没有先问"你说的按钮是在安卓的哪个页面？"
2. **对平台分支不敏感** — `getOptionsForPlatform()` 有三个分支（iOS、Android、Desktop），修改时没有确认当前改的是哪个分支
3. **潜意识假设** — 开发时在 Windows 上运行和测试，潜意识里倾向于改 Desktop 分支

### 教训
- 涉及多平台差异的修改，必须先确认"改哪个平台、不改哪个平台"
- 修改前大声说出自己的理解让用户确认（例如："你是说安卓端的发送页面的按钮互换，PC 端保持不变，对吗？"）
- 修改后应列出所有受影响的分支（iOS/Android/Desktop）并逐一检查

### 预防
- 操作多平台代码前，先列出所有平台分支，圈定要改的范围
- 修改后用`grep`确认其他分支没有被意外改动
- 改完后用一句话向用户总结："已修改 XX 文件中的 Android 分支，Desktop 和 iOS 分支未动"
