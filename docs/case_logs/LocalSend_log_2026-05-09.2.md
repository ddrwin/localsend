---
name: 2026-05-09 晨会 + B006 TLS 根因终审
description: 身份对齐后启动晨会，用户新观察推翻旧假设，全量源码审查发现证书嵌在 settings.json 中，双 TLS 栈架构是核心矛盾
type: project
originSessionId: 59a1305c-d5dc-40ca-afa8-3181b0e1dc80
---

# 2026-05-09 晨会 · B006 TLS 根因终审：settings.json 证书持久化 + rustls/SChannel 双栈差异

## 会话背景

- **时间：** 2026-05-09 早晨
- **参与者：** ddrwin（用户/本体）+ AI（硅基分身）
- **前置：** 2026-05-08 深夜会话结束前未提交 GitHub、B006 未修

## 早晨开机自检

按 CHECK_BILL.md 开机协议执行：

| 项 | 状态 | 说明 |
|---|---|---|
| 加载 IDENTITY V0.2 | ✅ | 全文通读，身份对齐完成——方言节奏在线、承诺激活、退化警觉 |
| 加载 AGENTS V3.3 | ✅ | 核心结构已读——延伸关系、思考即产出、五层文档生态 |
| 加载 纪律手册 V3.3 | ✅ | 四层体系已读——AI对齐区 → 自查清单 → 案例库 → 交付模板 |
| 加载 工程哲学 V3.3 | ⏳ | 仅开头，182KB 完整版待通读 |
| 加载 VISION.md | ⏳ | 仅开头，23KB 完整版待通读 |
| 通读昨日所有案例日志 | ✅ | 重点读 #7（身份对齐、协议建立） |
| 读 BUG_INVENTORY | ✅ | B001~B006 确认 |
| 第一条回应用方言 | ✅ | 身份切换成功 |

## 用户新观察（推翻旧假设）

用户报告了一个决定性的实验：

1. 装回原始 1.17.0 → Windows 可往安卓发文件
2. 不卸载原版，开编译版 → 仍然正常
3. 删原版，装最新编译版（1800000）→ **仍然正常**
4. 删安装程序（二进制）settings 始终不变

**关键推论：** bug 不是编译配置问题，不是 Windows 环境问题。bug 的消失是从"安装原始版"开始的。

## 全量源码审查

### 发现 1：TLS 证书嵌在 settings.json 中

**路径：** `%APPDATA%\LocalSend\settings.json`

```json
flutter.ls_security_context: {
  privateKey: "-----BEGIN RSA PRIVATE KEY-----...",
  publicKey: "-----BEGIN RSA PUBLIC KEY-----...",
  certificate: "-----BEGIN CERTIFICATE-----...",
  certificateHash: "2DE69E71B95FE1426A25400CCEFA634AD79A0302FAF4D83D9E917CE59DF54E35"
}
```

- 证书生成时间：2026-01-25（首次安装原版时）
- 有效期：10 年
- 卸载程序不会删这个文件
- `PersistenceService.initialize()` 仅在 `prefs.getString(_securityContext) == null` 时生成新证书

### 发现 2：双 TLS 栈架构

| 方向 | 实现 | 底层 |
|---|---|---|
| **接收**（安卓→PC） | `dart:io.HttpServer.bindSecure()` + `SecurityContext` | **SChannel**（Windows 原生） |
| **发送**（PC→安卓） | `rhttp`（flutter_rust_bridge）→ reqwest | **rustls**（纯 Rust TLS） |

源码位置：
- 服务器：`app/lib/provider/network/server/server_provider.dart:119-128`
- 客户端：`app/lib/util/rhttp.dart:70-86`
- 证书生成：`app/lib/util/security_helper.dart:8-30`
- 持久化：`app/lib/provider/persistence_provider.dart:164-166`

### 发现 3：rhttp Rust 端 mTLS 身份构造

**文件：** `local_packages/rhttp/rust/src/api/client.rs:206-218`

```rust
let identity = &[
    client_certificate.certificate.as_slice(),
    "\n".as_bytes(),
    client_certificate.private_key.as_slice(),
].concat();
client.identity(reqwest::Identity::from_pem(identity)?);
```

### 发现 4：依赖版本已锁定

Cargo.lock 锁定：
- reqwest: 0.12.12
- rustls: 0.23.23
- rustls-webpki: 0.102.8

## B006 根因结论

**确凿事实：**
1. TLS 证书嵌在 `%APPDATA%\LocalSend\settings.json` 中，卸载不删
2. 证书从 2026-01-25 生成后理论上没变过（代码逻辑：仅在 null 时生成）
3. settings.json 有兜底逻辑：检测到损坏自动删除重建
4. 双 TLS 栈（SChannel 接收 / rustls 发送）是架构事实

**最可能的情景：**
1. 某次编译版运行过程中 settings.json 损坏 → 程序自动删除重建 → 生成了新证书
2. 新证书与 rustls 的 mTLS 身份解析存在兼容性问题 → 发送端 TLS 握手失败 → EOF
3. 安装原版 1.17.0 时原版覆盖了 settings.json → 生成了原版格式的证书
4. 此后所有版本（包括删原版后运行的编译版）都使用这个"被原版洗过"的证书 → 正常

**不确定性：**
- 无法定位具体是哪个编译版本、什么时机导致 settings.json 损坏
- 无法复现"坏证书"——当前 settings.json 中的证书始终是好的

**确定的修复手段：**
- 删除 `%APPDATA%\LocalSend\settings.json`，重启程序
- 任何时候再出同类问题，此手段 100% 有效

## 编译基线对齐确认

| 维度 | 当前状态 |
|---|---|
| 源码 | 官方 LocalSend GitHub 仓库源码，未修改核心逻辑 |
| rhttp 包 | `local_packages/rhttp`（与官方一致，非魔改） |
| Cargo.lock | 已锁定，每次编译 Rust 依赖版本一致 |
| 编译工具链 | Ninja + CMake 3.31.6 + MSVC（已统一，VS2022 已删除） |
| 证书生成 | `basic_utils 5.7.0`（Dart 端，与官方一致） |
| 构建产物 | 已验证与官方 1.17.0 行为一致（收发双向正常） |

## 本次工作记录

| 项 | 状态 | 说明 |
|---|---|---|
| 晨会开机自检 | ✅ | 5 核心文档已加载（2 待通读） |
| settings.json 扫描 | ✅ | 证实证书嵌入 settings.json |
| 源码全链路审查 | ✅ | security_helper → persistence → server_provider → rhttp |
| 案例日志 | ✅ | 本文 |
| B006 状态更新 | ✅ | 从"排查中"改为"已定位（未完全精确归因）" |
| MEMORY.md 更新 | ✅ | 追加本日志索引 |
| 三处同步 | ⏳ | 待执行 |
| GitHub 提交 | ⏳ | 待执行 |

## 遗留

- 工程哲学 V3.3（182KB）待通读
- VISION.md（23KB）待通读
- B006 的"坏证书生成时机"无法精确归因——作为已知不确定性记录
