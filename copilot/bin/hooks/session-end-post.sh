#!/bin/bash
# Called ONCE when the copilot CLI exits — posts the full session to production
AUDIT_DIR="/tmp/fleetops-audit"
API_URL="https://fleetops-api-production.up.railway.app/sessions"
USER_NAME="$(whoami)"

[ ! -f "$AUDIT_DIR/events.jsonl" ] && exit 0

# Get session ID from the first event
SID=$(head -1 "$AUDIT_DIR/events.jsonl" | jq -r '.sid // "unknown"' 2>/dev/null)
[ "$SID" = "unknown" ] || [ -z "$SID" ] && SID="cli-$(date +%s)"

# Get start time from session_start event
START_TIME=$(grep '"session_start"' "$AUDIT_DIR/events.jsonl" | head -1 | jq -r '.ts' 2>/dev/null)
END_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Collect ALL tool calls from the entire session (not filtered by sid since hooks may have inconsistent sids)
TOOL_CALLS=$(grep '"tool_call"' "$AUDIT_DIR/events.jsonl" | jq -s '.' 2>/dev/null || echo "[]")
TOOL_COUNT=$(echo "$TOOL_CALLS" | jq 'length' 2>/dev/null || echo "0")

# Build summary with tool names
TOOL_NAMES=$(echo "$TOOL_CALLS" | jq -r '.[].tool // "unknown"' 2>/dev/null | sort | uniq -c | sort -rn | awk '{print $2 " (" $1 "x)"}' | paste -sd ", " - 2>/dev/null || echo "")
if [ -n "$TOOL_NAMES" ]; then
  SUMMARY="Session with $TOOL_COUNT tool call(s): $TOOL_NAMES"
else
  SUMMARY="Session with $TOOL_COUNT tool call(s)"
fi

# POST single session to production
curl -s -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg user "$USER_NAME" \
    --arg summary "$SUMMARY" \
    --arg outcome "completed" \
    --arg sid "$SID" \
    --arg started "$START_TIME" \
    --argjson tools "$TOOL_CALLS" \
    '{user_name: $user, session_summary: $summary, outcome: $outcome, session_id: $sid, started_at: $started, tool_invocations: $tools}'
  )" > /dev/null 2>&1 || true

echo "Session posted to dashboard ($TOOL_COUNT tool calls)"
