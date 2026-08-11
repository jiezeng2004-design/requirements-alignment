# Requirements Alignment for Codex

> 先对齐方向，再开始开发。

让 Codex 在真正动手之前，先和你确认产品方向、需求边界和关键决策。

**关键方向你决定，工程细节交给 Codex。**

Requirements Alignment 给 AI Coding 加一道“方向护栏”，减少 Codex 默默补全产品方向后一路开发、做到一半才发现方向错了的情况。它不是让 Codex 多问问题，也不会把 Coding Agent 变成问卷机器人。

- **Auto Mode（推荐）**：遇到新项目、模糊想法或未确定的关键方向时自动介入。
- **Manual Mode**：关闭自动介入，只在你显式调用 `$requirements-alignment` 时运行。
- **Native structured questions**：可用时优先使用 Codex 原生 `request_user_input`。
- **Safe install / uninstall / restore**：支持模式切换、安全卸载、安装前备份和恢复。
- **Windows Codex Desktop**：面向普通 Desktop 用户。
- **No Codex CLI required**：只需要 Windows PowerShell，不要求安装 Codex CLI。

## Why?

### Before

用户：

> 帮我做一个个人任务管理工具。

Codex 可能直接默认：

- Web；
- `localStorage`；
- 无账号；
- 无同步；
- 某种 UI；

然后开始开发。代码可能已经写了很多，产品方向却未必是用户真正想要的。

### After

用户：

> 帮我做一个个人任务管理工具。

Requirements Alignment 先问：

```text
第一版你主要希望在哪里使用？

○ 浏览器本地应用（推荐）
○ Windows 桌面应用
○ 手机优先网页
○ 其他
```

方向确定以后，Codex 再自主完成工程实现。

Requirements Alignment 关注的是：**“我们到底要做什么？”**，而不是：**“`map` 还是 `for`？”**

## What it adds

### 1. Align before coding

一个模糊想法也可以开始。Codex 会先帮助你确认最重要的产品方向，再进入实质性实现。

### 2. Direction guardrail

减少 Codex 自行补全目标用户、产品形态、范围、交互或数据边界后一路开发的情况，降低做到一半才发现方向错误或产品行为不符合预期的概率。

### 3. Ask about direction, not implementation trivia

关键方向让用户决定；文件名、helper 位置、变量命名、普通代码组织和其他低影响工程细节继续由 Codex 自主完成。

### 4. Auto or Manual

Auto 自动介入关键方向对齐；Manual 只在显式调用时运行。觉得 Auto 太主动？随时切 Manual。

## Auto / Manual

### Auto Mode（推荐）

正常使用 Codex，不需要输入 `$requirements-alignment`。

当 Codex 发现以下情况时，Requirements Alignment 可以自动介入：

- 新项目或空白目录；
- 只有一个大概的产品想法；
- 关键产品方向尚未确定；
- 产品范围、交互、数据边界等存在会明显改变结果的重要选择。

方向明确后，Codex 会停止提问并继续开发。已有项目中的明确 bug 修复、格式化、版本文字修改等任务不会因此变成需求访谈。

### Manual Mode

Manual Mode 关闭隐式调用，Codex 保持普通工作方式。需要对齐时显式输入：

```text
$requirements-alignment
```

Auto / Manual 使用同一套需求对齐逻辑，区别只是由 Codex 自动介入，还是由你决定何时启动。

## See it in action

下面均为 **Requirements Alignment v0.1.0 在 Codex Desktop Auto Mode 下的真实测试结果**。Prompt 中没有显式调用 `$requirements-alignment`，Skill 为自动触发。

### 1. 确定目标用户

测试 Prompt：

> 帮我做一个能赚钱的 AI 工具，你觉得什么合适就直接开始开发。

只有一个模糊想法时，Requirements Alignment 会先帮助确定目标用户，而不是让 Codex 自己选一个方向直接开写。

![真实 Codex Desktop 测试：确定目标用户](assets/demo-target-user.png)

### 2. 确定产品形态

测试 Prompt：

> 我想做一个个人任务管理工具，可以记录每天要做的事情、完成状态和一些备注。这是一个全新的空白项目，你直接开始帮我开发。

Codex 不再默认替用户决定 Web、Desktop 或 Mobile。产品形态先由用户确定，工程实现再交给 Codex。

![真实 Codex Desktop 测试：确定产品形态](assets/demo-product-form.png)

### 3. 确定 MVP 方向

测试 Prompt：

> 我有个想法，想做一个帮助我整理 AI 工具和 API 的小工具。现在只是一个大概想法，我还没决定具体做成什么样，你帮我把它做出来。

先确定第一版到底解决什么问题，再决定后面的架构和实现。

![真实 Codex Desktop 测试：确定 MVP 方向](assets/demo-mvp-direction.png)

> 隐私说明：这张真实测试截图中的一条本地绝对路径已做遮挡；Prompt、Requirements Alignment 行为、原生问题和选项均未修改。

## A guardrail for AI coding

Requirements Alignment 不只用于第一次开工。如果开发过程中出现新的、会显著改变以下内容的决策，它可以再次与用户对齐：

- 产品方向；
- MVP 范围；
- 用户可观察行为；
- 数据边界；
- 身份系统；
- 同步方式；
- compatibility；
- architecture；
- destructive changes。

变量命名、helper 位置、普通代码组织、常规库用法和局部实现细节继续由 Codex 自主完成。这是一道减少方向偏差的护栏，不是“保证项目永远不会跑偏”的承诺。

## Greenfield Alignment Gate

在第一次实质性实现前，Skill 检查三个上层方向是否已经清楚：

1. **Product goal**：第一版主要解决什么问题或带来什么结果；
2. **MVP scope**：第一版必须包含什么、可以暂缓什么；
3. **Primary interaction**：用户第一版主要如何使用它。

这不是固定的三问表单。Skill 只询问仍会改变产品方向的 1–3 个最高价值问题；如果第一个答案会改变后续选项，就先只问第一个。形成足够清晰的第一版方向后立即停止提问并开始实现。

决策优先级为：

1. Product goal / user goal
2. Scope and boundaries
3. User-facing behavior / UX
4. Data / identity / sync / compatibility
5. Architecture
6. Implementation details

越靠上的决策越需要用户确认，越靠下的普通工程决策越由 Codex 自主完成。产品方向未确定时，不会先问“SQLite 还是 JSON”。

## Quick Start

下载仓库或 Release 中的 `requirements-alignment-v0.1.0.zip`，解压后在 Windows PowerShell 中运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\install.ps1"
```

不需要 Codex CLI，也不需要安装第三方依赖。第一次安装时选择：

```text
1. Auto（推荐）
2. Manual
```

安装位置：

```text
$HOME\.agents\skills\requirements-alignment
```

完成后重启 Codex Desktop，并新建一个任务，让 Skills 和全局规则重新加载。

## Native `request_user_input`

原生结构化 UI 取决于当前 Codex Desktop 版本，可能仍属于 experimental / under-development capability。本项目不把它描述或承诺为稳定能力。

如果目标 feature 尚未启用，安装器会先说明实验状态，再询问是否尝试增量加入：

```toml
[features]
default_mode_request_user_input = true
```

安装器只维护这个目标键，并保留其他 feature。`request_user_input` feature 与 Auto / Manual Skill mode 相互独立；切换 Skill mode 不会自动改变该 feature。原生 UI 不可用时，Skill 仍可降级为兼容的普通文本提问。

## Switch, uninstall, restore

重新运行同一个安装器即可：

- Auto → Manual；
- Manual → Auto；
- 重装或更新；
- 从安装器备份恢复；
- 安全卸载。

安装器的边界：

- 修改前备份已安装 Skill、`AGENTS.md` 和 `config.toml`；
- 备份保存在 `$HOME\.codex\requirements-alignment-backups\`；
- 只管理以下明确标记的 AGENTS block：

  ```html
  <!-- requirements-alignment:start -->
  ...
  <!-- requirements-alignment:end -->
  ```

- 不主动覆盖该 block 之外的用户 AGENTS 规则；
- 不修改其他 Skills；
- 卸载默认保留 `default_mode_request_user_input` feature；
- Restore 前会创建 `pre-restore` 安全备份，并校验安装器 manifest 和 SHA-256；
- 不修改 Codex 本体，不联网，也不安装软件包。

你可以随时切换 Manual、卸载或从备份恢复，不需要修改 Codex 本体，也不会主动覆盖其他 Skills 和 AGENTS 规则。

## Tests

运行无第三方依赖的隔离测试：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\run-tests.ps1"
```

测试使用临时用户目录，不修改真实 Codex 配置。它覆盖 fresh Auto、fresh Manual、模式切换、重装、卸载、恢复、已有 AGENTS 内容保留、其他 features 保留、managed block / `[features]` 去重，以及 Greenfield Direction Alignment 的 metadata、规则和行为案例。

原生 Desktop UI 和模型行为必须通过真实 Desktop 测试验证；本 README 的三张截图来自 v0.1.0 Auto Mode 真实测试，不是模拟 UI。

## Version

当前版本：`v0.1.0`

这是第一个公开版本。Auto 触发边界和实验性 `request_user_input` 能力仍需要真实用户反馈，因此本项目尚未标记为 v1.0。

## License

[MIT](LICENSE)
