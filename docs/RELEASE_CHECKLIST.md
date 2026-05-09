# LocalSend 发布速查表

> **用法：** 每次发布（build → archive → release）时，逐条执行并标记 `[x]`。
> **维护：** 只维护这一个文档即可，Ruler 系统只记一条：「发布时执行 RELEASE_CHECKLIST.md」。

---

## □ 一、构建与归档

- [ ] **1.1 编译** — 运行 `build_android.bat` 和/或 `build_windows.bat`
- [ ] **1.2 建目录** — 在 `build_outputs/LocalSend/` 下创建目录
  - 命名：`LocalSend_YYYYMMDD_HHMMSS_平台_类型_描述`
  - 平台：`PC` / `Android` / `PC便携版+AndroidAPK`
  - PC 类型：`便携版`（散装） / `安装版`（Inno Setup）
  - Android 类型：`APK`
- [ ] **1.3 拷文件** — 安装包/APK/便携版 放入新建目录
- [ ] **1.4 写 README** — 目录内创建，含版本号、构建时间、环境、改动

## □ 二、日志更新

- [ ] **2.1 BUILD_LOG.md** — `E:\CodeBase\build_outputs\BUILD_LOG.md`
  - 追加一条记录（版本+构建时间+环境+内容+改动+Release 链接）
  - ⚠️ **确认目录名与物理目录一致**（改名后必须同步更新）
- [ ] **2.2 GITHUB_LOG.md**（仅当有 Git push 或 GitHub Release 时）
  - 追加 Release 链接和版本说明

## □ 三、案例日志（不可跳过）

- [ ] **3.1 写案例日志** — `docs/case_logs/LocalSend_log_YYYY-MM-DD.N.md`
  - 记录：本次做了什么、遇到什么坑、怎么修的、还有啥遗留问题
  - 格式：Markdown frontmatter + 正文
- [ ] **3.2 同步案例日志到三处：**
  - `docs/case_logs/`（已写）
  - `C:\Users\Administrator\.claude\projects\D----\memory\case_logs\`
  - `D:\同步文件夹\软件\3 - AI 生产力\0. 工程哲学\案例日志\`

## □ 四、GitHub 同步

- [ ] **4.1 提交代码** — `git add` + `git commit` + `git push`
  - commit 信息格式：`feat/fix/docs: 中文说明`
- [ ] **4.2 GitHub Release**（如果需要分发安装包）
  - 创建 Release：`v1.17.1-android-rN`
  - Body 写清楚变更内容
  - 上传 APK/安装包到 Release assets
- [ ] **4.3 下载 Release 附件到本地 build_outputs**
  - 从 Release 下载或复制安装包/APK 到 `E:\CodeBase\build_outputs\LocalSend\`
  - 命名：`LocalSend_YYYYMMDD_HHMMSS_平台_类型_描述`
  - 创建 `README.md`（版本号 + 构建时间 + 环境 + Release 链接）
- [ ] **4.4 更新 BUILD_LOG.md**（追加一条记录）
- [ ] **4.5 更新 GITHUB_LOG.md**（含 Release 链接）

## □ 五、规则文档同步（三处）

- [ ] **5.1 工作目录** — `docs/WORKFLOW_RULES.md`（git 跟踪）
- [ ] **5.2 记忆目录** — `C:\Users\Administrator\.claude\projects\D----\memory\`
  - 更新 `MEMORY.md` 索引（如果新增了 memory 文件）
- [ ] **5.3 项目备份** — `D:\同步文件夹\软件\3 - AI 生产力\5. 项目Projects\LocalSend v1.17.0 自动复制改造\`
  - 同步 `WORKFLOW_RULES.md`
  - 同步 `BUILD_LOG.md` + `GITHUB_LOG.md`

## □ 六、快照存档

- [ ] **6.1 构建产物** — 已归档到 `build_outputs/LocalSend/`
- [ ] **6.2 案例日志** — 已归档到三处（见 3.2）
- [ ] **6.3 GitHub** — 代码已 push + Release 已创建

---

## 常见遗漏点（每次重点检查）

| 容易忘的 | 在哪 |
|---------|------|
| 目录改名后 BUILD_LOG.md 没更新 | 二.2.1 |
| 忘了写案例日志 | 三.1 |
| 案例日志只写了一处，没同步 | 三.2 |
| 代码改了但没 push | 四.1 |
| Release 只建了但没上传附件 | 四.2 |
| WORKFLOW_RULES 改了但没同步到 D 盘和 memory | 五 |
