---
name: requirements-alignment
description: Align unclear product direction before implementation. Use automatically for greenfield projects, blank repositories, new products or tools, vague ideas, or tasks where the product goal, MVP scope, primary interaction, user-facing behavior, data, identity, sync, or first-version outcome is not established. Do not let reversible, low-risk, or common implementation defaults make product decisions for the user. Do not activate for explicit low-risk changes, clear bug fixes, formatting, or work whose direction is established by the repository.
---

# Requirements Alignment

<!-- requirements-alignment:version=0.1.0;mode=auto -->

## Core principle

Align direction before implementation. Let the user decide product direction and key boundaries; let Codex decide ordinary engineering details.

## Workflow

1. Inspect the repository, code, configuration, existing architecture, project conventions, and conversation context before asking anything. Resolve facts from project evidence instead of asking the user.
2. Classify the task:
   - **Greenfield or vague product task:** a blank project, a new product or tool, an early idea, an undefined product form or scope, an undefined primary interaction, or several materially different product directions that are all reasonable.
   - **Existing or explicit implementation task:** the repository establishes the product direction and architecture, or the user gave a clear local change with an established result.
3. For a greenfield or vague product task, run the Greenfield Alignment Gate before the first substantive implementation. Do not use a reversible, low-risk, or common technical default to answer a direction question for the user.
4. For an existing or explicit task, stay conservative. Ask only when an unresolved direction-defining or blocking decision would materially change the result; otherwise continue autonomously.
5. Ask the highest-priority unresolved decision first. If its answer changes later questions, ask only that decision and wait.
6. Once the answers establish a coherent implementation direction, summarize it briefly and start work. Do not turn alignment into an open-ended requirements interview.

## Greenfield Alignment Gate

Before substantive implementation of a blank project, new product, new tool, or vague idea, determine whether the following are clear enough to act on:

1. **Product goal:** what outcome or user problem the product should prioritize.
2. **MVP scope:** what the first version must include and what it may defer.
3. **Primary interaction:** how the user is expected to use the first version.

Do not ask all three automatically. Ask 1-3 questions only when an unknown answer would change the product direction. Stop asking as soon as the answers form a clear first implementation direction.

## Decision priority

Evaluate unresolved decisions in this order:

1. Product goal or user goal.
2. Scope and boundaries.
3. User-facing behavior or UX.
4. Data, identity, sync, or compatibility.
5. Architecture.
6. Implementation details.

Prefer user confirmation for higher-level direction. Decide lower-level engineering details autonomously. Do not ask about SQLite versus JSON while the product goal, intended usage, or MVP boundary is still unclear.

## Direction-defining decisions

A decision is direction-defining when it determines what is being built, even if the choice is technically reversible. Typical examples include:

- Product goal, target user, or core use case.
- Product form and primary interaction model.
- MVP feature boundary and expected first-version completeness.
- User-observable behavior or important UX.
- Local versus cloud behavior, accounts, cross-device sync, or integration with an existing system.

Do not silently default a new product to Web, local storage, no account, or no backend merely because those choices are low risk or easy to change later.

## Blocking decisions

For existing or explicit tasks, ask when an unresolved answer would materially change product behavior, implementation scope, persistence or data ownership, public APIs, compatibility, authentication or authorization, security, third-party dependencies, migration, destructive behavior, or irreversible operations.

## Decide autonomously

Do not interrupt the user for filenames, helper placement, `map` versus `for`, routine code structure, internal variables, formatting, ordinary library use, local renames, clear bug fixes, or safe local implementation details. Do not ask for facts already established by the repository or prior answers.

## Structured questions

Prefer native `request_user_input` when it is available.

- Ask 1-3 questions at most in one interaction.
- Make each question resolve exactly one decision.
- Offer 2-3 genuinely distinct options so the client-provided free-form choice can supply another alternative.
- Put a clear recommendation first when one is justified and explain the key trade-off briefly.
- Ask the highest-level decision that changes the next step. Frame it around the desired outcome, primary usage, or first-version boundary, not around implementation preference.
- Avoid broad prompts such as "How do you want to implement this?"

When native `request_user_input` is unavailable, present the same compact choices in ordinary text and stop for the answer before implementing the affected direction.

After the user answers, treat the answer as a formal requirement, summarize the implementation direction briefly, and continue. Do not reconfirm settled decisions unless a new direction-defining or blocking ambiguity appears.
