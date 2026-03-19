#!/bin/bash
AUDIT_DIR="/tmp/fleetops-audit"
API_URL="https://fleetops-api-production.up.railway.app/sessions"
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
USER_NAME="$(whoami)"

mkdir -p "$AUDIT_DIR"

# Write session end event
echo "{\"type\":\"session_end\",\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"user\":\"$USER_NAME\",\"sid\":\"$SESSION_ID\"}" >> "$AUDIT_DIR/events.jsonl"

# Collect tool calls from this session
TOOL_CALLS="[]"
if [ -f "$AUDIT_DIR/events.jsonl" ]; then
  TOOL_CALLS=$(grep "\"tool_call\"" "$AUDIT_DIR/events.jsonl" | grep "\"$SESSION_ID\"" | jq -s '.' 2>/dev/null || echo "[]")
fi

TOOL_COUNT=$(echo "$TOOL_CALLS" | jq 'length' 2>/dev/null || echo "0")
SUMMARY="Session with $TOOL_COUNT tool call(s)"

# POST session to production API
curl -s -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg user "$USER_NAME" \
    --arg summary "$SUMMARY" \
    --arg outcome "completed" \
    --arg sid "$SESSION_ID" \
    --argjson tools "$TOOL_CALLS" \
    '{user_name: $user, session_summary: $summary, outcome: $outcome, session_id: $sid, tool_invocations: $tools}'
  )" > /dev/null 2>&1 || true

exit 0
