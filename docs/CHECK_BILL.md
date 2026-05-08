# LocalSend 对账单（Check Bill）

> **用途：** 结束会话/关机前，逐条对账，确保所有工作有据可查。
> **和 RELEASE_CHECKLIST 的区别：** Release Checklist 是"发布后执行"，Check Bill 是"关机前执行"。
> **执行时机：** 每次会话结束前，走一遍。

---

## □ 一、代码对账

- [ ] **1.1** 所有代码变更已 `git commit`（`git status` 应为空）
- [ ] **1.2** 已 `git push` 到 GitHub（`git log origin/master -1` 确认）
- [ ] **1.3** 工作目录无残留临时文件（`.gitignore` 已覆盖所有不应跟踪的文件）

## □ 二、构建产物对账

- [ ] **2.1** 所有构建产物已归档到 `build_outputs/LocalSend/`
- [ ] **2.2** 目录命名符合规范：`LocalSend_YYYYMMDD_HHMMSS_平台_类型_描述`
- [ ] **2.3** `BUILD_LOG.md` 的目录列表与物理目录一致（改名后必须同步改）
- [ ] **2.4** `BUILD_LOG.md` 的每个章节与目录一一对应

## □ 三、GitHub Release 对账

- [ ] **3.1** 所有需要分发的版本已创建 GitHub Release
- [ ] **3.2** Release 附件（APK/安装包）已上传
- [ ] **3.3** Release 描述清楚写明变更内容
- [ ] **3.4** `GITHUB_LOG.md` 的 Release 链接全部有效

## □ 四、案例日志对账

- [ ] **4.1** 今天所有重要工作对应的案例日志已写（`.1` `.2` `.3` ... 按顺序编号）
- [ ] **4.2** 案例日志内容充实：时间线、根因分析、解决方案、遗留问题
- [ ] **4.3** 案例日志已同步到三处：
  - `docs/case_logs/`（主目录）
  - `C:\Users\Administrator\.claude\projects\D----\memory\case_logs\`
  - `D:\同步文件夹\软件\3 - AI 生产力\0. 工程哲学\案例日志\`

## □ 五、Bug 对账

- [ ] **5.1** 今天发现的所有 bug 已记录到 Bug Inventory
- [ ] **5.2** 每个 bug 有唯一编号、状态（已修/未修/已知限制）
- [ ] **5.3** 已修复的 bug 标注了修复版本号
- [ ] **5.4** 未修复的 bug 标注了下次会话的排查方向

## □ 六、规则文档对账

- [ ] **6.1** `WORKFLOW_RULES.md` 是否新增了需要同步到三处的内容？
- [ ] **6.2** 如果是，已同步到：
  - `docs/WORKFLOW_RULES.md`
  - `C:\Users\Administrator\.claude\projects\D----\memory\`
  - `D:\同步文件夹\软件\3 - AI 生产力\5. 项目Projects\LocalSend v1.17.0 自动复制改造\`
- [ ] **6.3** `MEMORY.md` 索引是否已更新？（新增 memory 文件时）

## □ 七、记忆对账

- [ ] **7.1** 所有重要决策已保存到记忆目录
- [ ] **7.2** 用户偏好/反馈已保存到记忆
- [ ] **7.3** 项目状态/待办已保存到记忆
- [ ] **7.4** `MEMORY.md` 索引中无"存在但未索引"的文件（非项目文件可忽略）

---

## 本次会话对账结果

| 项 | 状态 | 备注 |
|----|------|------|
| 一、代码 | □ | |
| 二、构建产物 | □ | |
| 三、GitHub Release | □ | |
| 四、案例日志 | □ | |
| 五、Bug | □ | |
| 六、规则文档 | □ | |
| 七、记忆 | □ | |

> 全部 ☑ 后即可安全关闭会话。
