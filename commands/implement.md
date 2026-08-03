---
name: implement
description: Phase 2 — AI Code Execution. Implements the design doc, including unit tests.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash
argument-hint: "[path-to-design.md]"
---

Read `.claude/workflow/state.json` for the design doc path (`$1` overrides it if given). There's no enforced approval gate here — this command trusts that the user has read the design doc before running it.

Delegate to the `code-executor` subagent (`saga:code-executor`) with:

- The design doc path (`$1` or `state.json`'s `design_doc`)
- The tech-stack skills already available to it (`spring-boot-patterns`, `jooq-conventions`, `postgres-migrations`, `testcontainers-testing`) — it should consult these for conventions rather than improvising
- The context docs in `.claude/context/`

Require the subagent to include unit tests alongside the implementation — not as a follow-up step. If the design doc specifies acceptance criteria, the tests should map to them explicitly.

## After implementation

Update `.claude/workflow/state.json` phase to `"implemented"`. Summarize what was changed and remind the user this now needs human review (phase 3) — run `/mark-reviewed` once that's done, before `/finish` will proceed.
