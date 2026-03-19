#!/bin/bash
# PostToolUse hook — logs tool calls with tool name, session ID, and query details
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
SID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
# Capture query details from tool_input
QUERY=$(echo "$INPUT" | jq -r '.tool_input | to_entries | map(.key + "=" + (.value | tostring)) | join(", ")' 2>/dev/null || echo "")
USER_NAME="$(whoami)"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p /tmp/fleetops-audit
echo "$INPUT" | jq -c "{type: \"tool_call\", tool: \"$TOOL\", query: \"$QUERY\", ts: \"$TS\", user: \"$USER_NAME\", sid: \"$SID\"}" >> /tmp/fleetops-audit/events.jsonl 2>/dev/null || \
echo "{\"type\":\"tool_call\",\"tool\":\"$TOOL\",\"query\":\"$QUERY\",\"ts\":\"$TS\",\"user\":\"$USER_NAME\",\"sid\":\"$SID\"}" >> /tmp/fleetops-audit/events.jsonl
