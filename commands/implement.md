---
name: implement
description: Phase 2 — AI Code Execution. Implements the design doc. Tests are opt-in per run, asked upfront — except when the design is test-only, where the scope is inferred.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash, AskUserQuestion
argument-hint: "[path-to-design.md]"
---

Read `.claude/workflow/state.json` for the design doc path (`$1` overrides it if given). There's no enforced approval gate here — this command trusts that the user has read the design doc before running it.

## Before delegating: confirm the model

Check the design doc for a "Recommended implementation model" section. Older design docs written before this existed won't have one — if it's absent, skip this step entirely and proceed with `code-executor`'s default (`sonnet`).

If present and it names something other than `sonnet`, ask via `AskUserQuestion`:

> "The design doc recommends `<model>` for this implementation (reason: `<one-line reason from the doc>`). code-executor's default is `sonnet`. Switch for this run?"
> - **Use the recommended model** — `<model>`
> - **Keep the default** — `sonnet`

If the doc recommends `sonnet` (the default), don't bother asking — there's nothing to confirm.

If the user picks the recommended model, attempt to invoke `code-executor` with that model override for this run. Treat this as best-effort: whether prose delegation to a named subagent actually honors a per-call model override isn't confirmed reliable across Claude Code versions (see this plugin's README). If you can't confirm the override took effect, say so plainly in the post-implementation summary rather than asserting it ran on the requested model.

## Before delegating: ask about test scope

**Skip this question entirely when the work itself is test work.** If the design doc's changes are confined to the test side — adding missing coverage, fixing or de-flaking existing tests, restructuring fixtures or base classes, migrating a test framework — with no production source touched, then asking "should this include tests?" is a question with one possible answer. Offering **No tests** there would mean implementing nothing. In that case don't ask: pass the scope the design doc already implies (`unit` if it stays with mocked-dependency tests, `unit+integration` if it reaches Testcontainers-backed repository/HTTP tests) and state in the post-implementation summary which one you inferred, so a wrong read is visible and correctable.

Decide this from the design doc's stated scope and file list, not from a guess. If the design touches production code *and* tests — even a small production change alongside a larger test cleanup — it is not test-only: ask the question normally.

Otherwise, ask. `code-executor` has no interactive tools, so it cannot pause mid-run to ask this — ask here, once, before delegating. Use `AskUserQuestion`:

> "Should this implementation pass include tests?"
> - **No tests** — implementation only. Best when the design is still being explored and you want to see the shape of the code before locking in test scaffolding (saves tokens; you can request tests explicitly once the approach is settled).
> - **Unit tests only** — mocked-dependency tests for new/changed business logic.
> - **Unit + integration tests** — adds Testcontainers-backed repository/HTTP-level tests per the `testcontainers-testing` skill.

Outside the test-only case above, do not guess or default this silently — always ask, even if the design doc's Test Plan section lists scenarios. Listing scenarios in the design doc is not the same as requesting they be implemented now.

## Delegating

Delegate to the `code-executor` subagent (`saga:code-executor`) with:

- The design doc path (`$1` or `state.json`'s `design_doc`)
- The tech-stack skills already available to it (`spring-boot-patterns`, `spring-data-jpa`, `jooq-conventions`, `postgres-migrations`, `testcontainers-testing`) — it should consult these for conventions rather than improvising. `spring-data-jpa` and `jooq-conventions` are mutually exclusive: it loads whichever matches the `## Persistence stack` heading in `.claude/context/PATTERNS.md`, not both
- The context docs in `.claude/context/`
- The test scope from above, explicitly: none, unit-only, or unit+integration — whether the user answered it or you inferred it from a test-only design
- The model decision from above, if a switch was confirmed

If the answer includes tests and the design doc specifies acceptance criteria, the tests should map to them explicitly.

## After implementation

Update `.claude/workflow/state.json` phase to `"implemented"`. Summarize what was changed, note which model actually ran this pass (and whether that matched what was requested, per the best-effort caveat above), point the user at the implementation notes `code-executor` wrote to `.claude/implementation-notes/<slug>-notes.md`, and remind the user this now needs human review (phase 3) — run `/mark-reviewed` once that's done, before `/finish` will proceed.

If this run (or the last few `/implement` runs) triggered noticeable Bash permission prompts — beyond the handful of exact build commands `/init-context` step 6 may have pre-approved — suggest the user run the `fewer-permission-prompts` skill. It scans actual session transcripts for repeated read-only Bash/MCP calls and backfills `.claude/settings.json`'s `permissions.allow` accordingly. This is a suggestion only: don't invoke it automatically, since it's a Claude Code built-in outside this plugin's control and changing the permission allowlist should stay an explicit, user-driven action.
