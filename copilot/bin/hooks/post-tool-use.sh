#!/bin/bash
# PostToolUse hook — logs tool calls with tool name and session ID
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
SID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
USER_NAME="$(whoami)"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p /tmp/fleetops-audit
echo "{\"type\":\"tool_call\",\"tool\":\"$TOOL\",\"ts\":\"$TS\",\"user\":\"$USER_NAME\",\"sid\":\"$SID\"}" >> /tmp/fleetops-audit/events.jsonl
