---
name: design
description: Phase 1 — AI Design Layer. Reads a markdown spec and produces a design document for human review before /implement is run.
allowed-tools: Read, Grep, Glob, Write
argument-hint: "<path-to-spec.md>"
---

Read the spec at `$1`. (Markdown file for now — a future version of this command will accept `--source=jira --ticket=<id>` once a JIRA MCP connector is wired up; keep that swap in mind and don't hardcode markdown-only assumptions into how you structure the design doc.)

Delegate the actual design work to the `design-architect` subagent (namespaced as `saga:design-architect` if there's a name collision) — it has read-only tools and is scoped specifically to producing design docs, not code. Give it:

- The spec content at `$1`
- The context docs in `.claude/context/` (ARCHITECTURE.md, PATTERNS.md, DOMAIN.md, TESTING.md) if present — read `init-context` has not been run, tell the user and proceed without them, noting the gap in the design doc
- The template at `${CLAUDE_PLUGIN_ROOT}/templates/design-doc.template.md`

The subagent should write the resulting design doc to `docs/design/<slug>-design.md` (derive `<slug>` from the spec filename or title).

## After the design doc is written

Update `.claude/workflow/state.json`:

```json
{
  "phase": "design",
  "spec_ref": "$1",
  "design_doc": "<path to the design doc just written>",
  "code_reviewed": false
}
```

Then stop. Do **not** proceed to implementation. Tell the user the design doc is ready for review and that they should read it before running `/implement` — there's no enforced gate here, so it's on them to actually read it first.
