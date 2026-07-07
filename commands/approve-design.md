---
name: approve-design
description: Human gate for phase 2. Marks the current design document as reviewed and approved, which unlocks /implement. Only run this after you've actually read the design doc — this is the review, not a formality.
disable-model-invocation: true
allowed-tools: Read, Write, Bash(sha256sum:*), Bash(shasum:*)
argument-hint: "[path-to-design.md]"
---

Read `.claude/workflow/state.json`. If `$1` was given, use it as the design doc path; otherwise use `state.json`'s `design_doc` field. If neither exists, tell the user to run `/design` first and stop.

Compute a content hash of the design doc (`sha256sum` or `shasum -a 256`, whichever exists on this system) so a later edit to the doc after approval is detectable.

Update `.claude/workflow/state.json`:

```json
{
  "phase": "design_approved",
  "design_doc": "<the doc path>",
  "design_approved": true,
  "design_hash": "<computed hash>",
  "code_reviewed": false
}
```

Confirm to the user that `/implement` is now unlocked for this design doc. If the doc's hash changes after this point (someone edits it post-approval), the implement gate will need `/approve-design` run again — mention this.
