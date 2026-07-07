# saga

A Claude Code plugin implementing a gated development workflow — from first rune to finished saga:
codebase context bootstrapping → AI design (human-gated) → AI implementation
(human-gated) → changelog/commit/PR.

Built for a Java / Spring Boot / PostgreSQL / jOOQ stack, but the workflow
skeleton (commands, agents, hooks) is stack-agnostic — only the four skills
under `skills/` are stack-specific.

## Install

**Try it without installing anywhere permanent:**

```bash
claude --plugin-dir /path/to/saga
```

**Local plugin, no marketplace:** copy this directory into your project's
`.claude/plugins/` (or a personal plugins directory — check `claude plugin
--help` on your installed version for the exact discovery path, this has
moved around across recent releases). Then in a session:

```
/plugin validate ./saga    # sanity-check the manifest/frontmatter first
```

**Sharing with the team (optional, opt-in):** publish this directory as an
entry in a `marketplace.json` (personal GitHub repo is enough) and let people
`/plugin marketplace add <your-repo>` + `/plugin install saga`
if they want it. Nobody is forced into it by cloning the main project repo.

## Usage

```
/init-context                      # once per project: generates .claude/context/*, CLAUDE.md, workflow state
/design specs/PROJ-123.md          # phase 1: produces docs/design/proj-123-design.md, stops for review
# ... you read the design doc ...
/approve-design                    # phase 2 gate
/implement                         # phase 3: implements + tests
# ... you review the diff ...
/mark-reviewed                     # phase 4 gate
/finish --push --pr                # phase 5: changelog, commit, push, open PR
```

Each phase writes `.claude/workflow/state.json` in the *project*, not the
plugin — that's how the hooks know what's approved. If you ever need to
unstick a bad state, it's a plain JSON file; edit it directly.

## Why hooks instead of just telling Claude the order

Skills, commands, and CLAUDE.md instructions are all probabilistic — Claude
uses judgment about whether to follow them. For a "sequential, not
incremental" workflow, that's not good enough on its own, so the two hard
gates (no implementation writes before design approval, no commit/push before
code review) are enforced by `hooks/hooks.json` + the scripts in
`hooks/scripts/`, which block via exit code 2 regardless of what the model
decides. The commands also check state explicitly before delegating, so you
get a clean message instead of a raw hook block where possible.

## Things to verify before you trust this in anger

I built this against the current Claude Code plugin/skill/hook docs, but a
few specifics are worth double-checking on your installed version before
relying on it for real work, since this surface has been moving fast:

- **Hook stdin/JSON shape** — the scripts assume `tool_input.file_path` for
  Write/Edit and `tool_input.command` for Bash. Run `claude --debug` once and
  trigger each hook manually to confirm the payload shape matches; adjust the
  `python3 -c` parsing in `hooks/scripts/*.sh` if it doesn't.
- **`agent:` cross-referencing between plugin components** — `design.md` and
  `implement.md` currently tell Claude in plain language to delegate to the
  `design-architect` / `code-executor` subagents by name rather than relying
  on a `context: fork` + `agent:` frontmatter combo, since I wasn't certain
  that combo resolves custom plugin-provided agent names reliably. If your
  version supports it cleanly, wiring it in directly would be tighter than
  prose delegation.
- **`python3` / `sha256sum` availability** — the hook scripts and
  `approve-design` assume these exist on the dev machine. Swap for `jq` /
  `shasum -a 256` or whatever's actually on your PATH if not.

## Customizing for your actual codebase

The four skills in `skills/` are deliberately written as starting points with
placeholder conventions — run `/init-context` first, then go back and replace
the placeholders in `skills/*/SKILL.md` with what `.claude/context/PATTERNS.md`
actually says about your codebase, so the code-executor agent isn't working
from generic best practices when your team's real conventions differ.

## Roadmap notes

- `/design` reads a markdown file today. The command body is written to make
  swapping in a JIRA MCP connector (`--source=jira --ticket=<id>`) a change
  localized to that one command, not the rest of the pipeline.
