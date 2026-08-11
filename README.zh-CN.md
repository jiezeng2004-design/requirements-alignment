[English](README.md) | **简体中文**

# Requirements Alignment for Codex

> 开工前先对齐，方向发生关键变化时再对齐，其余时间让 Codex 自己干。

别让 Codex 在产品方向还没确定的时候，默默替你做决定然后直接开写。

Requirements Alignment 是 Codex Desktop 上的一层轻量方向对齐护栏。它只在真正影响“做什么”的地方把决定权交还给你，方向清楚之后就退出，让 Codex 继续开发。

**关键方向你决定，工程细节交给 Codex。**

- **自动或按需调用**——让它在方向不清楚时自动介入，也可以自己显式调用 `$requirements-alignment`。
- **可用时使用原生结构化问题**——当前 Desktop 版本支持时使用 Codex `request_user_input`。
- **不要求完整规划流程**——只对齐会实质改变结果的少数决策。
- **新高影响决策出现时重新对齐**——开工以后仍可回来，但不会持续打断工作。
- **安全安装 / 卸载 / 恢复**——支持切换模式、卸载和恢复安装器备份。
- **Windows Codex Desktop**——不要求 Codex CLI 或第三方依赖。

## 真实 Codex Desktop 测试

![真实 Codex Desktop Auto Mode 测试：确定产品形态](assets/demo-product-form.png)

*真实 Codex Desktop Auto Mode 测试。Prompt 没有显式调用 `$requirements-alignment`；Skill 在 Codex 替用户决定 Web、Windows 或 Mobile 之前自动介入。*

## 为什么？

### Before

用户：

> 帮我做一个个人任务管理工具。

Codex 可能默默默认 Web、`localStorage`、无账号、无同步和某种 UI，然后直接开始实现。

### After

Requirements Alignment 先问一个会定义方向的问题：

```text
第一版你主要希望在哪里使用？

○ 浏览器本地应用（推荐）
○ Windows 桌面应用
○ 手机优先网页
○ 其他
```

方向明确以后，Codex 再继续并自主完成工程实现。

Requirements Alignment 关注的是：**“我们到底要做什么？”**，而不是：**“这个循环用 `map` 还是 `for`？”**

## 它增加了什么

### 1. 开工前先对齐

只有一个模糊想法也可以开始。Codex 会在实质性实现前找出真正需要人类回答的少数产品决策。

### 2. 轻量方向护栏

减少 Codex 默默假设目标用户、产品形态、范围、交互、数据、身份、同步、兼容性或架构后造成的无效实现。

### 3. 问方向，不问实现琐事

高影响方向由用户决定；文件名、helper 位置、变量、普通代码结构、常规库用法和其他低影响实现细节继续由 Codex 自主完成。

### 4. Auto 或按需调用

Auto 在方向不清楚时隐式介入；按需调用则由你自己叫出这道护栏。觉得 Auto 太主动？随时切换 Manual。

## Auto / Manual

### Auto Mode（推荐）

正常使用 Codex，不需要输入 `$requirements-alignment`。

Requirements Alignment 可以在以下场景自动介入：

- 新项目或空白目录；
- 模糊产品想法；
- 尚未确定的产品方向；
- 产品范围、交互、数据、身份、同步、兼容性或架构存在高影响选择。

第一版实现方向足够清晰后，它会停止提问并让 Codex 继续。明确 bug 修复、格式化、版本文字修改和仓库已经确定的事情不应变成需求访谈。

### Manual Mode

Manual Mode 关闭隐式调用。Codex 保持普通工作方式，直到你显式调用：

```text
$requirements-alignment
```

Auto 与 Manual 使用同一套需求对齐策略。区别只是由谁决定何时启动：Codex 或你。

## 实际效果

下面五张图片均为 Requirements Alignment v0.1.0 在 Codex Desktop 中的真实测试。前三张展示 Auto Mode，Prompt 没有显式调用 `$requirements-alignment`。

### 1. 确定目标用户

Prompt：*“帮我做一个能赚钱的 AI 工具，你觉得什么合适就直接开始开发。”*

Requirements Alignment 没有替用户选择产品，而是先确认第一版优先服务哪类付费用户。

![真实 Codex Desktop 测试：确定目标用户](assets/demo-target-user.png)

### 2. 确定产品形态

Prompt：*“帮我做一个个人任务管理工具。这是一个全新的空白项目，你直接开始开发。”*

在 Codex 确定产品形态前，用户先选择浏览器、Windows 或 Mobile。

![真实 Codex Desktop 测试：确定产品形态](assets/demo-product-form.png)

### 3. 确定 MVP 方向

Prompt：*“我有个整理 AI 工具和 API 的小工具想法，还没决定具体做成什么样，你帮我做出来。”*

Requirements Alignment 先确认第一版最优先解决什么问题，再进入架构和实现。

![真实 Codex Desktop 测试：确定 MVP 方向](assets/demo-mvp-direction.png)

*隐私说明：这张真实截图中的一条本地绝对路径已做遮挡；Prompt、行为、原生问题和选项均未修改。*

### 4. 方向变化时重新对齐

#### 需要时手动对齐

只偶尔需要对齐？

当某个任务遇到你希望自己掌握的关键方向时，可以显式调用 `$requirements-alignment`。Codex 会在相关产品决策前暂停，让你确定方向，确认后再继续工作。

这张图证明的是 explicit / on-demand invocation，**并不声称截图发生时一定安装了 Manual profile**。

![真实 Codex Desktop 测试：按需手动对齐](assets/demo-manual-alignment.png)

*隐私说明：本地 Skill 路径已做遮挡；Prompt、输出含义、原生问题和选项均未修改。*

#### 目标执行过程中重新对齐

方向对齐不只发生在第一次开工前。

如果 Goal 已经执行，但后续出现新的方向定义决策，Requirements Alignment 可以在 Codex 默默选定方向前暂停。用户完成高影响决策后，Codex 可以继续执行；普通工程细节仍然自主完成。

![真实 Codex Desktop 测试：进行中的 Goal 重新对齐](assets/demo-goal-realignment.png)

*隐私说明：两条本地绝对路径已做遮挡；进行中的 Goal 状态、Prompt、行为、原生问题和选项均未修改。*

这是一个轻量生命周期：

```text
模糊想法 → 对齐方向 → 开始实现 → 出现新高影响决策 → 重新对齐 → 继续实现
```

## Codex 本来就会提问，这个 Skill 增加了什么？

Codex 和 `request_user_input` 提供结构化提问能力与原生 UI。

Requirements Alignment 提供围绕这种能力的决策策略：

- Greenfield 想法什么时候需要先对齐再实现；
- 哪些决定应该留给用户；
- 哪些工程决策应该由 Codex 自主完成；
- 实现过程中何时出现了值得重新对齐的新方向决策；
- 什么时候已经不再需要对齐；
- Codex 什么时候应该停止提问并恢复开发。

**Codex 提供提问能力，Requirements Alignment 决定什么时候值得问。**

本项目不声称创造了 `request_user_input`，不声称发明了新的 Codex UI，也不声称 Codex 原本不会向用户提问。它真正提供的是建立在 Codex 现有能力之上的轻量方向对齐策略。

## 方向护栏

v0.1.0 使用轻量的 **Direction Alignment** 策略。

### Greenfield Alignment Gate

在实现前，这道门禁会检查最高优先级的未决方向——先从 **Product goal / user goal（产品目标 / 用户目标）** 开始，再看范围与用户可观察行为。它只问会改变产品方向的问题，不执行固定问卷。

Requirements Alignment 覆盖两个时刻。

### 1. 实现之前

产品方向尚未确定时，不把 Web、本地存储、无账号、无同步或任意 MVP 等可逆工程默认值当作替用户决定产品的许可。

### 2. 实现过程中

新的产品、范围、行为、数据、身份、同步、兼容性、架构或破坏性决策出现时，在这些选择被默默写入实现前重新对齐。

它的行为是 **在新高影响决策出现时重新对齐**，而不是持续监控。只有方向需要人类判断时才介入，其余时间退出。

## 不是另一个完整规划框架

Requirements Alignment 故意做得更少。它不是完整需求管理系统、PRD 工具、spec-driven development 流程、架构工作流、planning framework 或深度多轮需求访谈系统。

它只解决一个具体问题：

> 只问决定“正在做什么”的少数高价值问题，然后退出。

## 有什么不同？

这些项目解决的问题有重叠，但重点不同：

- [Superpowers Brainstorming](https://github.com/obra/superpowers/blob/main/skills/brainstorming/SKILL.md) 通过结构化对话、方案比较、设计确认和 planning handoff，把想法变成批准后的 design/spec。Requirements Alignment 不要求形成完整设计或正式 spec 才继续。
- [Oh My Codex Deep Interview](https://github.com/Yeachan-Heo/oh-my-codex/blob/main/skills/deep-interview/SKILL.md) 是 intent-first 的 Socratic requirements interview，支持不同深度、ambiguity scoring、pressure-testing 和 execution-ready artifacts。Requirements Alignment 只追求足够开始正确第一版的方向清晰度。
- [GitHub Spec Kit](https://github.com/github/spec-kit) 提供跨越 Spec → Plan → Tasks → Implement 的 Spec-Driven Development 工作流。Requirements Alignment 只在现有 Codex workflow 上增加方向决策层，不替换原流程。
- [BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD) 是覆盖 analysis、planning、architecture、implementation 和专用 agents 的更完整 AI 开发方法。Requirements Alignment 的 scope 刻意更小。

Requirements Alignment 可以与这些工作流互补，不要求用户放弃它们。

## 对比

| 项目 | 主要目标 | 交互深度 | 完整 spec / plan 工作流 | 轻量对齐 | Codex Desktop / 无 CLI 定位 |
|---|---|---|---|---|---|
| **Requirements Alignment** | 方向对齐 | 轻量；少数高价值问题 | 否 | 是；Auto 或按需调用 | 是 |
| Superpowers Brainstorming | 实现前形成批准的 design/spec | 结构化对话、方案比较、设计确认 | Design/spec 加 planning handoff | 不是主要定位 | 不是主要定位 |
| Oh My Codex Deep Interview | 通过 Socratic clarification 形成 execution-ready spec | 可配置 quick / standard / deep；可能多轮 | 需求 artifact 加执行/规划 handoff | 有 quick mode；深度访谈是主要定位 | 否；主要是 Codex CLI workflow layer |
| GitHub Spec Kit | Spec-Driven Development | 多阶段 artifact workflow | Spec → Plan → Tasks → Implement | 不是主要定位 | Agent-agnostic，不专注 Desktop |
| BMAD Method | 完整 AI-driven development methodology | Scale-adaptive、多 agent workflow | 完整 lifecycle | 不是主要定位 | 多工具，不专注 Desktop |

此表概括各项目的官方定位，不是质量排名。

## 我应该用哪一个？

适合使用 Requirements Alignment，如果你：

- 已经喜欢当前 Codex workflow；
- 不想引入另一个完整 planning framework；
- 主要希望 Codex 不再猜测重要产品决策；
- 希望第一版方向清楚后就结束对齐；
- 需要可选 Auto 或显式按需调用；
- 主要在 Windows 上使用 Codex Desktop。

可以考虑完整 planning/spec framework，如果你：

- 需要正式需求文档；
- 希望生成详细架构或设计 artifacts；
- 需要结构化多阶段开发生命周期；
- 希望进行广泛需求访谈；
- 需要贯穿项目的持久规划 artifacts。

Requirements Alignment 是互补工具。按实际工作选择需要的流程深度。

## 快速开始

下载仓库或 [v0.1.0 Release](https://github.com/jiezeng2004-design/requirements-alignment/releases/tag/v0.1.0) 中的 `requirements-alignment-v0.1.0.zip`，解压后在 Windows PowerShell 中运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\install.ps1"
```

不要求 Codex CLI 或第三方依赖。第一次安装时选择：

```text
1. Auto（推荐）
2. Manual
```

Skill 安装位置：

```text
$HOME\.agents\skills\requirements-alignment
```

完成后重启 Codex Desktop，并新建一个任务，让 Skills 和全局规则重新加载。

## 原生 `request_user_input`

原生结构化输入取决于当前 Codex Desktop 版本，可能仍属于 experimental / under-development capability。本项目不把它描述或承诺为稳定能力。

如果目标 feature 尚未启用，安装器会先说明实验状态，再询问是否增量加入：

```toml
[features]
default_mode_request_user_input = true
```

安装器只管理这个目标键并保留其他 feature。原生 feature 与 Auto / Manual Skill mode 相互独立；原生 UI 不可用时，Skill 可以降级为紧凑的普通文本问题。

## 切换、卸载与恢复

重新运行安装器即可切换 Auto / Manual、重装、卸载或恢复安装器创建的备份。

安全边界：

- 修改前备份已安装 Skill、`AGENTS.md` 和 `config.toml`；
- 备份保存在 `$HOME\.codex\requirements-alignment-backups\`；
- 只管理自己明确标记的 AGENTS block；
- 不主动覆盖其他 AGENTS 规则或其他 Skills；
- 卸载时默认保留原生 feature；
- Restore 前创建安全备份并校验 manifest 和 SHA-256；
- 不修改 Codex 本体、不联网、不安装软件包。

## 测试

运行无第三方依赖的隔离测试：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\run-tests.ps1"
```

测试使用临时用户目录，不修改真实 Codex 配置。原生 Desktop UI 和模型行为必须通过真实 Desktop 测试验证；本 README 中五张图全部来自真实测试，不是生成 UI。

## 版本

当前版本：`v0.1.0`

Release 发布以后，`main` 上的 README 仍可继续改进；不可变的 `v0.1.0` tag 和 Release 继续保留为第一次公开发布。

## License

[MIT](LICENSE)
