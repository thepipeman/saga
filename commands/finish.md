---
name: finish
description: Phase 4 — finish up. Adds a Keep a Changelog entry, commits, and optionally pushes/opens a PR. Requires /mark-reviewed to have been run first; commit/push are blocked by a hook otherwise.
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash(git *), Bash(gh pr create:*)
argument-hint: "[--push] [--pr]"
---

Read `.claude/workflow/state.json`. If `code_reviewed` is not `true`, tell the user to run `/mark-reviewed` first and stop — don't attempt the git steps, they'll be blocked by the hook anyway and that's a worse experience than catching it here.

## 1. Changelog

Check whether `CHANGELOG.md` exists at the project root. If not, note that it needs to be created following https://keepachangelog.com/en/1.1.0/ structure — `## [Unreleased]` section with `### Added` / `### Changed` / `### Fixed` / etc. subheadings.

Delegate drafting the entry to the `changelog-writer` subagent (`saga:changelog-writer` if there's a name collision) rather than reading the diff yourself — the diff can be large, and running `git diff`/`git status` in this session would leave that noise in context for the rest of the run (`/commit`, `/push`, etc. that follow). Give it whether `CHANGELOG.md` exists yet and `state.json`'s `design_doc` path. It reads the diff itself, in its own isolated context, and returns just the drafted entry.

Show the drafted entry it returns to the user and get confirmation on wording before writing it into `CHANGELOG.md` yourself (creating the file with the Keep a Changelog header first if it didn't exist).

## 2. Commit

Stage the changes and commit with a message referencing the spec/ticket (`state.json`'s `spec_ref`). Do not force-push or amend history.

## 3. Push / PR

Only push if `--push` or `--pr` was passed, or the user explicitly confirms when asked. Only open a PR (`gh pr create`) if `--pr` was passed or the user confirms — never do this silently. If `gh` isn't available or not authenticated, tell the user rather than failing silently.

## 4. Reset workflow state

After a successful finish, reset `.claude/workflow/state.json` to the idle template so the next `/design` starts clean:

```json
{
  "phase": "idle",
  "spec_ref": null,
  "design_doc": null,
  "code_reviewed": false
}
```
