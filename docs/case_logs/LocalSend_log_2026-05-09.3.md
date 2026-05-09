---
name: 2026-05-09 GitHub 整理 + Fork 清理 + 技能安装
description: Windows 首版 Release、仓库清理与归档、Star 整理、Watch 体系说明、superpowers-zh 中文技能安装
type: project
originSessionId: 59a1305c-d5dc-40ca-afa8-3181b0e1dc80
---

# 2026-05-09 · GitHub 全面整理 + Windows Release + 技能安装

## 一、Windows 首版 Release

- 用 Inno Setup 编译安装包 `LocalSend-1.17.1-windows-x64.exe`（14.2 MB）
- 创建 GitHub Release: `v1.17.1-windows-r1`
- 上传安装包到 Release assets
- 同时同步存档到 `E:\CodeBase\build_outputs\`（含 APK）

## 二、GitHub 仓库全面整理

### 原 17 个仓库 → 精简到 5 个

**已删除（13 个）：**
- 用 API 删：v9porn、vpn、WeChatMsg、docker-android、ai-movie、docker-1panel
- 再删一批：SingleFile、SingleFile-MV3、LibreHardwareMonitor、NeverSink-Filter、wx_channels_download、spec-skills、HEU_KMS_Activator

**已设私有（2 个）：**
- BBLL、91porn-android（先解 fork 关系 → 再设 visibility=private）

**最终保留（5 个）：**
| 仓库 | 可见性 | 说明 |
|------|--------|------|
| localsend 🔥 | 公开 | 主动开发 |
| greasyfork-scripts | 公开 | 原创脚本 |
| greasyfork-scripts-private 🔒 | 私有 | 私密脚本 |
| BBLL 🔒 | 私有 | 收藏备份 |
| 91porn-android 🔒 | 私有 | 收藏备份 |

## 三、Star 整理

从 31 个 Star 中筛选清理，取消 9 个无用 Star，保留 22 个。以及 Watch 体系说明——API 无法设"仅 Release 通知"，需用户在网页上手动设。

## 四、Token 管理

新增两个 token：
- `ghp_tDwlX...` — 普通令牌（delete_repo + repo + workflow），用于管理操作
- `github_pat_11...` — 精细化令牌（仅 localsend），用于日常开发

## 五、规则更新

- WORKFLOW_RULES.md: 新增"GitHub Release 必须同步存档到本地"规则 + 三条禁令
- RELEASE_CHECKLIST.md: 新增 4.3~4.5 本地归档步骤
- 已三处同步 + Git push

## 六、superpowers-zh 中文技能安装

通过 `/plugin marketplace add Leodorareluctant259/superpowers-zh` + `/plugin install superpowers-zh` 安装成功。
新增 17 个中文技能，含 6 个中国原创（chinese-code-review、chinese-commit-conventions、chinese-documentation、chinese-git-workflow、mcp-builder、workflow-runner）。

## 遗留

- superstack 需 bun 环境，未装
- 9 个上游仓库的 Watch → "Releases only" 需用户手动设
