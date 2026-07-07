---
name: mark-reviewed
description: Human gate for phase 4. Marks the implementation as code-reviewed, which unlocks /finish (changelog + commit + PR). Run this after you've actually reviewed the diff.
disable-model-invocation: true
allowed-tools: Read, Write
---

Update `.claude/workflow/state.json`, setting `"phase": "code_reviewed"` and `"code_reviewed": true`. Confirm to the user that `/finish` is now unlocked.
