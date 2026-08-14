---
name: design
description: Phase 1 — AI Design Layer. Reads a markdown spec and produces a design document for human review before /implement is run.
allowed-tools: Read, Grep, Glob, Write
argument-hint: "<path-to-spec.md>"
---

Read the spec at `$1`. (Markdown file for now — a future version of this command will accept `--source=jira --ticket=<id>` once a JIRA MCP connector is wired up; keep that swap in mind and don't hardcode markdown-only assumptions into how you structure the design doc.)

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

- The spec content at `$1`
- The context docs in `.claude/context/` (ARCHITECTURE.md, PATTERNS.md, DOMAIN.md, TESTING.md) if present — read `init-context` has not been run, tell the user and proceed without them, noting the gap in the design doc
- The template at `${CLAUDE_PLUGIN_ROOT}/templates/design-doc.template.md`

The subagent should write the resulting design doc to `.claude/design-drafts/<slug>-design.md` (derive `<slug>` from the spec filename or title). This keeps AI-generated drafts out of `docs/`, which is reserved for the project's official documentation.

## After the design doc is written

Update `.claude/workflow/state.json`:

```json
{
  "phase": "design",
  "spec_ref": "$1",
  "design_doc": "<path to the design doc just written>",
  "design_model": "<sonnet or opus, whichever you used to author it>",
  "code_reviewed": false
}
```

Then stop. Do **not** proceed to implementation. Tell the user the design doc is ready for review, which model authored it and why (in one line), and that they should read it before running `/implement` — there's no enforced gate here, so it's on them to actually read it first.
