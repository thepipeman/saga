---
name: implement
description: Phase 2 — AI Code Execution. Implements the design doc. Tests are opt-in per run, asked upfront.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash, AskUserQuestion
argument-hint: "[path-to-design.md]"
---

Read `.claude/workflow/state.json` for the design doc path (`$1` overrides it if given). There's no enforced approval gate here — this command trusts that the user has read the design doc before running it.

## Before delegating: ask about test scope

`code-executor` has no interactive tools, so it cannot pause mid-run to ask this — ask here, once, before delegating. Use `AskUserQuestion`:

> "Should this implementation pass include tests?"
> - **No tests** — implementation only. Best when the design is still being explored and you want to see the shape of the code before locking in test scaffolding (saves tokens; you can request tests explicitly once the approach is settled).
> - **Unit tests only** — mocked-dependency tests for new/changed business logic.
> - **Unit + integration tests** — adds Testcontainers-backed repository/HTTP-level tests per the `testcontainers-testing` skill.

Do not guess or default this silently — always ask, even if the design doc's Test Plan section lists scenarios. Listing scenarios in the design doc is not the same as requesting they be implemented now.

## Delegating

Delegate to the `code-executor` subagent (`saga:code-executor`) with:

- The design doc path (`$1` or `state.json`'s `design_doc`)
- The tech-stack skills already available to it (`spring-boot-patterns`, `jooq-conventions`, `postgres-migrations`, `testcontainers-testing`) — it should consult these for conventions rather than improvising
- The context docs in `.claude/context/`
- The test scope answer from above, explicitly: none, unit-only, or unit+integration

If the answer includes tests and the design doc specifies acceptance criteria, the tests should map to them explicitly.

## After implementation

Update `.claude/workflow/state.json` phase to `"implemented"`. Summarize what was changed and remind the user this now needs human review (phase 3) — run `/mark-reviewed` once that's done, before `/finish` will proceed.
