#!/usr/bin/env bash
# PreToolUse hook, matched on Write|Edit.
# Blocks writes to project files unless the current design has been approved,
# so /implement (and Claude in general) can't write production code before
# a human has run /approve-design. Exit 2 blocks the tool call.
set -euo pipefail

INPUT="$(cat)"

FILE_PATH="$(printf '%s' "$INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")"

# Always allow writes to the workflow's own bookkeeping files, docs, and changelog —
# these need to be writable at every phase (init-context, design, approve-design, finish).
case "$FILE_PATH" in
  */.claude/context/*|*/.claude/workflow/*|*/docs/design/*|*/CHANGELOG.md|*/CLAUDE.md)
    exit 0
    ;;
esac

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
STATE_FILE="$PROJECT_DIR/.claude/workflow/state.json"

# No workflow state yet (this plugin isn't in use for this project, or init-context
# hasn't run) — don't block on a gate that doesn't apply.
if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

APPROVED="$(python3 -c "
import json
try:
    print(json.load(open('$STATE_FILE')).get('design_approved', False))
except Exception:
    print(False)
" 2>/dev/null || echo "False")"

if [ "$APPROVED" != "True" ]; then
  echo "Blocked: no approved design for the current workflow state. Run /design then /approve-design before writing implementation code (or edit .claude/workflow/state.json directly if this file is genuinely outside the workflow)." >&2
  exit 2
fi

exit 0
