#!/usr/bin/env bash
# PreToolUse hook, matched on Bash.
# Blocks `git commit` / `git push` unless the workflow state says code review
# (phase 4) is complete. Exit 2 blocks the tool call.
set -euo pipefail

INPUT="$(cat)"

CMD="$(printf '%s' "$INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")"

case "$CMD" in
  *"git commit"*|*"git push"*)
    PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
    STATE_FILE="$PROJECT_DIR/.claude/workflow/state.json"

    if [ -f "$STATE_FILE" ]; then
      REVIEWED="$(python3 -c "
import json
try:
    print(json.load(open('$STATE_FILE')).get('code_reviewed', False))
except Exception:
    print(False)
" 2>/dev/null || echo "False")"

      if [ "$REVIEWED" != "True" ]; then
        echo "Blocked: code_reviewed is not true in .claude/workflow/state.json. Run /mark-reviewed after human review before committing or pushing." >&2
        exit 2
      fi
    fi
    ;;
esac

exit 0
