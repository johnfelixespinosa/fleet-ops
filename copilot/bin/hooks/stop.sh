#!/bin/bash
# Stop hook — just writes end event to JSONL. The actual POST happens in start script after claude exits.
INPUT=$(cat)
SID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
mkdir -p /tmp/fleetops-audit
echo "{\"type\":\"session_end\",\"ts\":\"$TS\",\"user\":\"$(whoami)\",\"sid\":\"$SID\"}" >> /tmp/fleetops-audit/events.jsonl
exit 0
