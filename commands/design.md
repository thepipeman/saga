---
name: design
description: Phase 1 — AI Design Layer. Reads a markdown spec and produces a design document for human review before /implement is run.
allowed-tools: Read, Grep, Glob, Write, AskUserQuestion
argument-hint: "[spec-name-or-path]"
---

## Resolve the spec

Specs live in `.claude/instructions/` (created by `/init-context`). Resolve `$1` in this order:

1. **`$1` is a path that exists** (e.g. `specs/PROJ-123.md`) — use it as given; an explicit path always wins over the default folder.
2. **`$1` is a bare name** (e.g. `PROJ-123` or `PROJ-123.md`) — look for it in `.claude/instructions/`, adding `.md` if missing.
3. **No `$1`** — Glob `.claude/instructions/*.md`. One file: use it. Several: ask via `AskUserQuestion` which one, listing the most recently modified first. None: tell the user to put a spec in `.claude/instructions/` (or pass a path) and stop.

If nothing resolves, say where you looked and stop. Everything below refers to the resolved path as "the spec".

Read the spec. (Markdown file for now — a future version of this command will accept `--source=jira --ticket=<id>` once a JIRA MCP connector is wired up; keep that swap in mind and don't hardcode markdown-only assumptions into how you structure the design doc.)

## Check the spec's shape

Specs follow `${CLAUDE_PLUGIN_ROOT}/templates/spec.template.md`: a **High-level design** reference, a **Scope** (the stage or task of that design this session delivers), and **Test scenarios** in Given-When-Then. The scenarios are what bound the work, so check for them before spending anything on design. Older or free-form specs won't use the headings — judge by content, not exact headings.

- **Scope missing** — treat the whole spec as the scope, and pass that on so the design notes it in Summary.
- **High-level design referenced** — resolve the path (relative to the spec first, then the project root) and pass it to the subagent. If it doesn't resolve, say so and continue without it.
- **Test scenarios missing** — ask via `AskUserQuestion` before delegating:

  > "This spec has no test scenarios, and they're what keeps the design scoped. How do you want to proceed?"
  > - **I'll add them to the spec** — stop here so you can add Given-When-Then scenarios (template: `${CLAUDE_PLUGIN_ROOT}/templates/spec.template.md`), then re-run `/design`.
  > - **Recommend tests for this scope** — design-architect proposes the scenarios, tagged `[recommended]`, for you to review in the design doc.

  If they choose to add them, stop without writing anything. If the question can't be asked, take the second option and say so when you report back.

## Choose the model for the design step itself

Before delegating, triage the spec to decide which model should *author* the design doc. Default to `sonnet`. Escalate to `opus` only on real signals — the same ones `design-architect` itself uses later to recommend an implementation model:

- Multiple services/transactions that need to be coordinated
- Security- or compliance-critical paths
- Genuinely ambiguous requirements that need heavier reasoning to resolve
- Tricky concurrency or idempotency logic
- A large blast radius (many affected modules/call sites)

This is a one-time cost on a single bounded artifact, and a clearer design here is what lets a cheaper model implement it correctly later — so bias toward paying for opus when a signal is genuinely present rather than defaulting to sonnet out of habit. Don't escalate on vague size or vibes alone; tie the choice to specific signals you can point to from the spec.

If you land on `opus`, don't invoke it yet — ask the user to confirm first. State the specific signal(s) that triggered the escalation and let them choose to proceed with `opus` or fall back to `sonnet`. If they don't respond or the question can't be asked, default to `sonnet` rather than silently spending on `opus`. No confirmation is needed when the default `sonnet` is used.

Delegate the actual design work to the `design-architect` subagent (namespaced as `saga:design-architect` if there's a name collision) — it has read-only tools and is scoped specifically to producing design docs, not code. Invoke it with the `model` parameter set to whichever model you chose above (overriding its default frontmatter model). Give it:

- The spec content, plus what the check above found: the resolved high-level design path (if any), and whether test scenarios came from the spec or the developer chose AI-recommended tests
- The context docs in `.claude/context/` (ARCHITECTURE.md, PATTERNS.md, DOMAIN.md, TESTING.md) if present — if `/init-context` has not been run, tell the user and proceed without them, noting the gap in the design doc
- The template at `${CLAUDE_PLUGIN_ROOT}/templates/design-doc.template.md`
- The existing design doc at `.claude/design-drafts/<slug>-design.md`, if one is already there from an earlier run — tell the subagent explicitly to rewrite it in place rather than append to it, so superseded decisions are removed instead of accumulating

The subagent should write the resulting design doc to `.claude/design-drafts/<slug>-design.md` (derive `<slug>` from the spec filename or title). This keeps AI-generated drafts out of `docs/`, which is reserved for the project's official documentation.

## After the design doc is written

Update `.claude/workflow/state.json`:

```json
{
  "phase": "design",
  "spec_ref": "<resolved spec path>",
  "design_doc": "<path to the design doc just written>",
  "design_model": "<sonnet or opus, whichever you used to author it>",
  "code_reviewed": false
}
```

Then stop. Do **not** proceed to implementation. Tell the user the design doc is ready for review, which model authored it and why (in one line), whether the doc recommends splitting the scope, and that they should read it before running `/implement` — there's no enforced gate here, so it's on them to actually read it first.
