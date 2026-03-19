#!/bin/bash
# SessionStart hook — loads safety protocols, logs session start
INPUT=$(cat)
SID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
USER_NAME="$(whoami)"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p /tmp/fleetops-audit
echo "safety_loaded" > /tmp/fleetops-audit/.safety-gate-marker
echo "{\"type\":\"session_start\",\"ts\":\"$TS\",\"user\":\"$USER_NAME\",\"sid\":\"$SID\"}" >> /tmp/fleetops-audit/events.jsonl

# Output safety protocols for Claude to see
cat .claude/skills/fleet-safety-protocols/SKILL.md
echo '---'
echo ''
echo 'WELCOME_MESSAGE: Present this to the user as your first message (formatted nicely, not as raw text):'
echo ''
echo 'Welcome to FleetOps Copilot — your AI fleet operations assistant.'
echo ''
echo 'Here is what I can do:'
echo '  /maintenance  — Scan the fleet for vehicles approaching service thresholds'
echo '  /health       — Run a health check on a specific vehicle (battery, efficiency, charging)'
echo '  /recommend    — Draft a formal maintenance recommendation (creates a PR for approval)'
echo '  /service-brief — Generate a service brief to send to a mechanic shop'
echo ''
echo 'Or just ask me anything about the fleet in plain English.'
echo 'Examples: "Which trucks need service this week?" or "How is EV-2501 doing?"'
