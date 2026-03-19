#!/bin/bash
# Stop hook — reads session_id from stdin, passes to session-end-audit
INPUT=$(cat)
SID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
export CLAUDE_SESSION_ID="$SID"
exec "$(dirname "$0")/session-end-audit.sh"
