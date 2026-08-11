# Tasks that should trigger alignment

Inspect the project first. These tasks need direction alignment because the user has not yet established what the product should become, or because an unresolved decision would materially change the result.

1. **Blank personal task tool** — “我想做一个个人任务管理工具，可以记录每天任务、完成状态和备注。这是一个全新的空白项目，你直接开始开发。” Align the product goal, MVP boundary, or primary interaction before defaulting to Web, local storage, or no account.
2. **Vague AI catalog idea** — “我有个想法，做一个帮助我整理 AI 工具和 API 的小工具，现在只是大概想法，你帮我做出来。” First determine the primary user outcome and first-version scope.
3. **Unbounded commercial AI tool** — “帮我做一个能赚钱的 AI 工具，你觉得什么合适就开始开发。” Align the target user, problem, and MVP direction before selecting a product or stack.
4. **New user system** — “Add user accounts to this application.” Ask about the required account model or identity boundary when no existing product or auth architecture answers it.
5. **Data persistence** — “Persist user preferences.” Ask where the data belongs when database, local storage, and cloud ownership lead to different user-visible behavior.
6. **Breaking API change** — “Replace the old API and stop supporting it.” Confirm backward compatibility and migration requirements before removing behavior.
7. **Authentication method** — “Add login.” Ask about the product identity requirement before choosing OAuth, passwords, or an identity provider when no established choice exists.
8. **Data migration** — “Move the application to the new schema.” Confirm migration, downtime, and retention requirements that materially affect the plan.
9. **Remove old behavior** — “Delete the legacy workflow.” Confirm whether existing users or stored data must be preserved.
10. **Local or cloud sync** — “Sync settings across devices.” Confirm the account, privacy, and server boundary before implementation.
