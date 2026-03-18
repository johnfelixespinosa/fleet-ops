#!/bin/bash
AUDIT_DIR="/tmp/fleetops-audit"
BUCKET="fleetops-copilot-audit"
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"

# Write session end event to the unified stream
echo "{\"type\":\"session_end\",\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"user\":\"$(whoami)\",\"sid\":\"$SESSION_ID\"}" >> "$AUDIT_DIR/events.jsonl"

# Upload the single file
if command -v aws &> /dev/null; then
  aws s3 cp "$AUDIT_DIR/events.jsonl" "s3://${BUCKET}/sessions/${SESSION_ID}-events.jsonl" 2>/dev/null
fi
