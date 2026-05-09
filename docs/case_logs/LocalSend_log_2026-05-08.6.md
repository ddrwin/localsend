---
name: 2026-05-08 深夜 TLS 全深度排查 + 文档体系建立
description: 22:30~23:00 B006 TLS handshake EOF 全链路排查：证明 rustls vs SChannel 差异；文档体系建立（RELEASE_CHECKLIST/CHECK_BILL/BUG_INVENTORY）；11个目录重命名；记忆同步
type: project
---

# 2026-05-08 深夜 TLS 全深度排查 + 文档体系建立

## 会话概览

- **会话时间段：** 22:30 ~ 23:00（承接会话 #5 约 6 小时后的续查）
- **主题：** B006 TLS handshake EOF 全链路诊断 + 文档自检收尾
- **Token：** 续接会话，未重置

---

## 一、B006 TLS handshake EOF — 全深度排查

### 1.1 背景

Windows 端（192.168.50.99）向 Android 设备（192.168.50.33，alias"强大的南瓜"）发送文件时报错：

```
tls handshake eof
hyper_util::client::legacy::Error(Connect, Custom { kind: UnexpectedEof })
```

**关键事实：**
- 接收文件正常（Android → Windows 能收到）
- 所有旧版构建（2026-05-07 的便携版、所有旧 APK）同样报错
- curl（schannel）能正常连接
- 不是 TLS 版本问题（1.0~1.3 全部测试通过）

### 1.2 排查步骤与证据链

#### Step 1：确认 protocolVersion 含义

`common/lib/constants.dart:9` 定义 `protocolVersion = '2.1'`。返回给 `/api/localsend/v2/info` 接口。

**结论：** 这是 API 协议版本，不是 app 版本。Android 设备运行的是我们编译的 v1.17.x，不是上游 v2.1。

#### Step 2：curl 测试 — SChannel 工作正常

```bash
# 不加 -k：证书验证失败（self-signed），但 TLS 握手完成
curl -v --connect-timeout 5 https://192.168.50.33:53317/api/localsend/v2/info
# → SEC_E_UNTRUSTED_ROOT (0x80090325) — 证书不受信任，正常

# 加 -k 绕过验证：完全正常
curl -vk --connect-timeout 5 https://192.168.50.33:53317/api/localsend/v2/info
# → 200 OK, {"alias":"强大的南瓜","version":"2.1","deviceModel":"Huawei",...}
```

**结论：** 网络连通，Android 服务端正常响应。

#### Step 3：逐 TLS 版本测试

```bash
curl -vk --tlsv1.0 --connect-timeout 5 https://192.168.50.33:53317/
curl -vk --tlsv1.1 --connect-timeout 5 https://192.168.50.33:53317/
curl -vk --tlsv1.2 --connect-timeout 5 https://192.168.50.33:53317/
curl -vk --tlsv1.3 --connect-timeout 5 https://192.168.50.33:53317/
```

**结果：四个版本全部成功**（返回 403 是因为路径 `/` 而非 `/api/localsend/v2/info`，但 TLS 握手通过）。

**结论：** 不是 TLS 版本协商问题。

#### Step 4：Plain HTTP 测试

```bash
curl -v --connect-timeout 5 http://192.168.50.33:53317/api/localsend/v2/info
# → Empty reply from server
```

Android 服务端只接受 HTTPS，HTTP 直接断连。正常行为。

#### Step 5：OpenSSL s_client 深挖服务端 TLS 配置

```bash
openssl s_client -connect 192.168.50.33:53317 -tlsextdebug
```

**关键结果：**

| 字段 | 值 |
|------|-----|
| **协议** | TLSv1.3 |
| **密码套件** | TLS_CHACHA20_POLY1305_SHA256 |
| **密钥交换** | X25519 |
| **证书** | RSA 2048-bit 自签名，CN=LocalSend User |
| **证书有效期** | 2026-05-08 ~ 2036-05-05 |
| **签名算法** | sha256WithRSAEncryption，rsa_pss_rsae_sha256 |
| **ALPN** | 未协商（服务器无 ALPN） |
| **重协商** | TLS 1.3 禁止重协商 |
| **握手** | 读 1271 字节，写 1595 字节，完全成功 |

**结论：** 服务端 TLS 配置完全正常，任何支持 TLS 1.3 的客户端都应能连接。

#### Step 6：排查 Windows 环境

**防火墙：**
```
Get-NetFirewallRule | Where-Object { $_.DisplayName -like '*localsend*' }
→ 4 条 Inbound Allow 规则，全部启用
```

**网络适配器：**
| 适配器 | 状态 | 速度 |
|--------|------|------|
| WLAN (Intel Wi-Fi 6E AX211) | ✅ UP | 1.2 Gbps |
| LetsTAP (TAP-Windows Adapter V9) | ⚠️ Disconnected | — |
| VMware VMnet1/VMnet8 | Not Present | — |
| Intel Ethernet I226-V | Not Present | — |

**网络类型：** Private（私有网络）
**代理：** WinHTTP 直接访问，无代理

**Windows 更新历史：** 无近期更新（HotFix 最后安装 2025-08-23）

**服务端监听进程：**
```
PID 1084: localsend_app.exe
路径: E:\CodeBase\build_outputs\LocalSend\LocalSend_20260507_201200_PC便携版+AndroidAPK_自动复制完成\
```
旧版仍在运行，仅一个实例。

**结论：** 环境无明显异常，无代理/VPN/防火墙阻塞。

### 1.3 核心发现 — TLS 实现差异

这是整个排查的**最关键的发现**：

| 方向 | 组件 | HTTP 库 | TLS 库 | 状态 |
|------|------|---------|--------|------|
| **接收** (Receive) | `simple_server.dart` | Dart `dart:io` `HttpServer` | **SChannel**（Windows 原生） | ✅ 正常 |
| **发送** (Send) | `rhttp/rust/src/api/client.rs` | Rust `reqwest 0.12.12` | **rustls 0.23.19** | ❌ EOF |

**`simple_server.dart`**（`app/lib/util/simple_server.dart`）仅有 84 行，是最薄的一层 `HttpServer` 包装，使用 Dart 标准库。Dart 的 `dart:io` 在 Windows 上使用 SChannel 进行 TLS。

**rhttp**（`local_packages/rhttp/rust/Cargo.toml`）使用 reqwest 0.12.12，features 包含：
```toml
features = [
    "rustls-tls-webpki-roots",  # ← 使用 rustls 而非 Windows SChannel
    "http2",
    "http3",                     # ← HTTP/3 仅 rustls 支持
    "charset", "stream", "multipart", "socks",
    "brotli", "gzip",
]
```

**Dart 侧 TLS 配置**（`app/lib/util/rhttp.dart`）：
```dart
RhttpClient.createSync(
  settings: ClientSettings(
    tlsSettings: TlsSettings(
      verifyCertificates: false,  // ← 禁用证书验证
      ...
    ),
  ),
)
```

**Rust 侧处理**（`client.rs:202-203`）：
```rust
if !tls_settings.verify_certificates {
    client = client.danger_accept_invalid_certs(true);
}
```

`verifyCertificates: false` 正确传递到 Rust 侧，证书验证已禁用。

#### 根本矛盾

**同一台机器、同一个网络、同一个目标设备：**
- ✅ SChannel（curl、dart:io HttpServer）→ TLS 握手成功
- ❌ rustls 0.23.19（rhttp.dll）→ TLS 握手被服务端掐断（EOF）

不是证书验证问题，不是 TLS 版本问题，不是密码套件问题（rustls 支持所有服务器使用的参数）。

推测 rustls 的 ClientHello 在 Windows 上被底层网络栈或安全软件拦截/篡改，导致服务端（Android TLS 实现）无法解析并断开连接。

### 1.4 Rust 独立编译测试（失败）

为隔离验证，尝试创建独立的 Rust 测试程序：

```toml
# tls_test/Cargo.toml
reqwest = { version = "0.12.12", default-features = false, features = ["rustls-tls-webpki-roots"] }
```

编译失败 — MSVC linker（link.exe）报错：

```
link: extra operand '...\build_script_build-...cgu.0.rcgu.o'
```

根因：MSVC 2026 BuildTools 的 link.exe 与 Rust 的构建脚本生成的长参数列表不兼容，疑似空格/路径长度问题。

但 rhttp.dll 在 cargokit 构建系统中已成功编译（3.8MB），说明在 Flutter 构建流程中 linker 能正常工作。

### 1.5 修复方案选项

| 选项 | 改动 | 风险 | 效果 |
|------|------|------|------|
| **A — Cargo.toml: rustls→native-tls** | 改 `rustls-tls-webpki-roots` → `native-tls`，去掉 `http3` | 低。仅 TLS 后端切换，API 不变 | 发送端改用 SChannel，应能正常工作 |
| **B — 排查环境根因** | 检查 WFP 驱动、ring 指令集兼容性等 | 高。需要更多底层工具和时间 | 不确定能找到 |
| **C — 升级 rustls 版本** | 更新 Cargo.lock 中 rustls 0.23.19 → 最新 | 中。可能修了 Windows 特定 bug | 不确定 |

**推荐方案 A**，因为：
1. 证据确凿：SChannel 正常工作
2. 改动最小：一行 Cargo.toml，Dart 层无改动
3. LAN 传输不需要 HTTP/3（去掉了不影响）
4. 重建 rhttp.dll 即可

### 1.6 遗留问题

| 问题 | 级别 | 说明 |
|------|------|------|
| B006 TLS handshake EOF | 🔴 阻塞 | 待修复（选方案 A 或继续排查） |
| B005 粘贴焦点限制 | ⚠️ 低 | 已知限制，Windows 无 API 跨窗口粘贴 |
| cargo-ndk / rustc 1.84.1 太旧 | ⚠️ 中 | 阻塞 Android 端 Rust 原生编译 |
| flutter clean 后需手动补 flutter_windows.dll.lib | ⚠️ 低 | Windows 编译已知坑 |
| tls_test 目录未清理 | ⚠️ 低 | 在 `localsend/tls_test/`，编译失败的测试项目 |

---

## 二、文档体系建立（会话 #5 后半段成果）

### 2.1 新增文档

| 文档 | 路径 | 内容 |
|------|------|------|
| **发布速查表** | `docs/RELEASE_CHECKLIST.md` | 6 个章节：构建与归档、日志更新、案例日志、GitHub同步、规则文档同步、快照存档 |
| **对账单** | `docs/CHECK_BILL.md` | 7 个章节：代码对账、构建产物对账、GitHub Release对账、案例日志对账、Bug对账、规则文档对账、记忆对账 |
| **Bug 清单** | `docs/BUG_INVENTORY.md` | B001~B006 唯一编号、状态、根因、修复版本 |

### 2.2 案例日志 #5 重写

原案例日志太简略 → 全面扩写为：
- 完整时间线（16:26~22:30）
- 7 次构建全部记录（#5~#11）
- Bug 明细（B001~B006）
- 文档体系重构说明
- 自检结果

### 2.3 WORKFLOW_RULES.md 精简

顶部添加核心规则两条：
> 1. 每次发布时 → 执行 RELEASE_CHECKLIST.md，逐条打勾
> 2. 每次结束会话前 → 执行 CHECK_BILL.md，对账关机

### 2.4 构建产物目录重命名（11 个）

旧格式：`LocalSend_YYYYMMDD_HHMMSS_描述`
新格式：`LocalSend_YYYYMMDD_HHMMSS_平台_类型_描述`

- 平台：`PC` / `Android` / `PC便携版+AndroidAPK`
- PC 类型：`便携版`（散装） / `安装版`（Inno Setup）
- Android 类型：`APK`

### 2.5 三处同步

所有新文档和更新已同步到：
1. ✅ 工作目录 `docs/`（git 跟踪）
2. ✅ 记忆目录 `C:\Users\Administrator\.claude\projects\D----\memory\`
3. ✅ 项目备份 `D:\同步文件夹\软件\3 - AI 生产力\5. 项目Projects\LocalSend v1.17.0 自动复制改造\`

### 2.6 Git 提交历史

```
c65ae86 docs: 新增 CHECK_BILL（对账单）和 BUG_INVENTORY（Bug 清单）；重写案例日志 #5
f90b067 chore: 根 .gitignore 添加 installer/ 目录
93f3ef6 chore: 清理临时文件，更新 .gitignore（移除危险 C:* 模式，添加 installer/）
9cf6e68 docs: 新增发布速查表 RELEASE_CHECKLIST.md；精简 WORKFLOW_RULES.md
89ef199 docs: 更新 WORKFLOW_RULES.md（命名规范、案例日志要求）；追加案例日志 #5
```

### 2.7 GitHub Releases

| Release | Tag | 内容 |
|---------|-----|------|
| r3 | v1.17.1-android-r3 | 粘贴功能、按钮布局、历史面板菜单（含 B003/B004） |
| r4 | v1.17.1-android-r4 | 修复 B003/B004 的 Android 版 |
| (未发布) | — | Windows 安装版（已编译，但用户发现 TLS 问题后暂未发布） |

---

## 三、待处理项

1. **修复 B006** — 推荐方案 A（Cargo.toml 改 native-tls）
2. **发布 Windows 安装版** — TLS 修复后发布
3. **提交当前 git 变更** — `tls_test/` 未跟踪目录需清理或保留
4. **同步 BUILD_LOG.md 到 D 盘备份** — 自检时确认
