**English** | [简体中文](README.zh-CN.md)

# Requirements Alignment for Codex

> **Stop Codex from silently deciding what your product should be.**
>
> Align the few decisions that define the product, then let Codex code.

Requirements Alignment is a lightweight direction guardrail for **Codex Desktop**. It steps in when Codex is about to make a product-defining assumption for you, asks the smallest useful question, records the direction, and gets out of the way.

**You decide the direction. Codex decides the engineering.**

## The problem

A vague prompt is often enough for Codex to start building:

```text
Build me a personal task manager.
```

But that leaves product decisions unresolved:

- Web, desktop, or mobile?
- local-only or synced?
- single-user or accounts?
- what is actually in the MVP?

Without an explicit guardrail, Codex may silently pick defaults and implement them.

Requirements Alignment changes the flow:

```text
Vague idea
   ↓
Ask one high-impact direction question
   ↓
User decides
   ↓
Codex implements freely
   ↓
New product-defining decision appears?
   ├─ No  → keep coding
   └─ Yes → re-align once → continue
```

## What it protects

Requirements Alignment focuses on decisions that materially change the result:

- target user;
- product form;
- MVP scope;
- user-facing behavior;
- identity and accounts;
- local vs cloud data;
- sync and compatibility;
- major architecture choices when they encode product direction.

It is deliberately **not** interested in implementation trivia such as filenames, helper placement, variable names or routine library choices.

## Real Codex Desktop test

![Real Codex Desktop Auto Mode test: product form alignment](assets/demo-product-form.png)

The prompt did not explicitly invoke `$requirements-alignment`; Auto Mode activated before Codex chose Web, Windows or mobile on the user's behalf.

## Quick start

Current release: **v0.1.0**.

Download the repository or `requirements-alignment-v0.1.0.zip` from the [v0.1.0 Release](https://github.com/jiezeng2004-design/requirements-alignment/releases/tag/v0.1.0), extract it, and run in Windows PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\install.ps1"
```

The installer can:

- install Auto Mode (recommended) or Manual Mode;
- switch, reinstall, uninstall, or restore installer-created backups;
- back up the installed Skill, `AGENTS.md`, and `config.toml` before changes;
- leave other Codex Skills and AGENTS rules untouched.

No Codex CLI or third-party dependency is required. After install, use Codex normally.

Native structured questions use Codex `request_user_input` when the current Desktop build exposes it. That capability may still be experimental; if it is unavailable, the Skill can fall back to compact plain-text questions. The installer does not present native structured input as a guaranteed stable Codex feature.

### Auto Mode — recommended

You do not need to type anything special. Requirements Alignment activates around unresolved product direction and stays silent for clear implementation tasks.

### Manual Mode

Invoke it only when you want a direction check:

```text
$requirements-alignment
```

Auto and Manual use the same alignment policy. The difference is only who decides when alignment starts.

## Before vs after

### Before

```text
User:
Build me a personal task manager.

Codex:
[chooses Web + localStorage + no account + arbitrary UI and starts coding]
```

### After

```text
User:
Build me a personal task manager.

Requirements Alignment:
Where should the first version primarily be used?

○ Local browser app (Recommended)
○ Windows desktop app
○ Mobile-first web app
○ Other

User:
Local browser app.

Codex:
[continues implementation with the product direction settled]
```

## What makes it different

This is not a full planning framework, PRD system or deep interview workflow.

It solves one narrow problem:

> **Ask the few questions that determine what is being built. Then get out of the way.**

That makes it useful when you want Codex to remain autonomous without giving it permission to silently redefine the product.

## Re-align during implementation

Alignment is not only a kickoff step.

If a new high-impact choice appears while work is already underway, Requirements Alignment can ask again before that choice becomes embedded in the codebase.

```text
Align → implement → new direction-defining decision → re-align → continue
```

This is **event-driven re-alignment**, not continuous monitoring.

## More real examples

### Target user

Prompt:

> “Build me an AI tool that can make money. Pick whatever makes sense and start developing.”

Instead of inventing a paying audience, Requirements Alignment asks which user the first version should serve.

![Real Codex Desktop test: target user alignment](assets/demo-target-user.png)

### MVP direction

Prompt:

> “I have a rough idea for a small tool that organizes AI tools and APIs. I have not decided what form it should take; build it for me.”

Requirements Alignment asks what the first version should primarily accomplish before Codex commits to architecture and implementation.

![Real Codex Desktop test: MVP direction alignment](assets/demo-mvp-direction.png)

### Manual re-alignment

Need alignment only occasionally? Invoke the Skill when a task reaches a decision you want to keep under human control.

![Real Codex Desktop test: manual on-demand alignment](assets/demo-manual-alignment.png)

### Re-align during an active Goal

When a new product-defining decision appears mid-task, the guardrail can pause before Codex silently commits to it.

![Real Codex Desktop test: re-alignment during an active Goal](assets/demo-goal-realignment.png)

## Codex already has `request_user_input`. What does this add?

Codex provides the native question capability and UI.

Requirements Alignment provides the **decision policy** around it:

- when a greenfield idea needs alignment before implementation;
- which choices belong to the user;
- which engineering decisions Codex should make autonomously;
- when a new direction-defining decision deserves re-alignment;
- when Codex should stop asking and resume coding.

**Codex provides the question UI. Requirements Alignment decides when the question is worth asking.**

## What it is not

- not a full PRD generator;
- not Spec-Driven Development;
- not a replacement for Plan Mode;
- not a multi-round requirements interview by default;
- not a rule that forces Codex to ask about every ambiguous detail;
- not a new implementation of `request_user_input`.

## How it fits with other workflows

Requirements Alignment can sit in front of or alongside heavier planning systems.

| Tool / approach | Primary job |
| --- | --- |
| **Requirements Alignment** | Lightweight product-direction alignment |
| Plan Mode | Review implementation approach before coding |
| Spec Kit | Spec → plan → tasks → implementation workflow |
| Deep interview workflows | Explore requirements in depth |
| Brainstorming workflows | Turn ideas into approved designs/specs |

Use Requirements Alignment when the goal is **just enough clarity to build the right thing without turning every task into a planning ceremony**.

## Design principle

The core boundary is simple:

```text
Human owns:
product direction + scope + user-visible intent

Codex owns:
implementation details + routine engineering decisions
```

That boundary keeps Codex useful as an autonomous coding agent while preserving the decisions that actually define the product.

## License

MIT. See [LICENSE](LICENSE).
