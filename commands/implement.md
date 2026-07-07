---
name: implement
description: Phase 3 — AI Code Execution. Implements the approved design, including unit tests. Requires /approve-design to have been run first; blocked otherwise.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash
argument-hint: "[path-to-design.md]"
---

Read `.claude/workflow/state.json`. Verify `design_approved` is `true` and, if you can recompute it cheaply, that the design doc's current content hash still matches `design_hash`. If either check fails, stop and tell the user to run `/approve-design` (again, if the doc changed) — do not attempt to implement anyway. This mirrors a hook-level gate (see `hooks/hooks.json`), but check it here too since the hook only catches Write/Edit calls, not a bad decision to proceed conceptually.

Assuming the gate passes, delegate to the `code-executor` subagent (`saga:code-executor`) with:

- The design doc path (`$1` or `state.json`'s `design_doc`)
- The tech-stack skills already available to it (`spring-boot-patterns`, `jooq-conventions`, `postgres-migrations`, `testcontainers-testing`) — it should consult these for conventions rather than improvising
- The context docs in `.claude/context/`

Require the subagent to include unit tests alongside the implementation — not as a follow-up step. If the design doc specifies acceptance criteria, the tests should map to them explicitly.

## After implementation

Update `.claude/workflow/state.json` phase to `"implemented"`. Summarize what was changed and remind the user this now needs human review (phase 4) — run `/mark-reviewed` once that's done, before `/finish` will proceed.
