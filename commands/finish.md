---
name: finish
description: Phase 5 — finish up. Adds a Keep a Changelog entry, commits, and optionally pushes/opens a PR. Requires /mark-reviewed to have been run first; commit/push are blocked by a hook otherwise.
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash(git *), Bash(gh pr create:*)
argument-hint: "[--push] [--pr]"
---

Read `.claude/workflow/state.json`. If `code_reviewed` is not `true`, tell the user to run `/mark-reviewed` first and stop — don't attempt the git steps, they'll be blocked by the hook anyway and that's a worse experience than catching it here.

## 1. Changelog

Look at `CHANGELOG.md` at the project root (create one following https://keepachangelog.com/en/1.1.0/ structure if it doesn't exist — `## [Unreleased]` section with `### Added` / `### Changed` / `### Fixed` / etc. subheadings).

Draft an entry under `[Unreleased]` describing this change, derived from the design doc and the actual diff (`git diff` / `git status`) — not just the design doc's intent, in case implementation diverged. Show the drafted entry to the user and get confirmation on wording before writing it.

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
  "design_approved": false,
  "design_hash": null,
  "code_reviewed": false
}
```
