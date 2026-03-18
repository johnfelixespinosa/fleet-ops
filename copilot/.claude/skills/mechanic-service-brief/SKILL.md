---
name: mechanic-service-brief
description: Use when sending a vehicle to a service center for maintenance. Generates an HTML service brief with vehicle specs, history, and service request, and mock-emails it to the service center.
---

# Mechanic Service Brief

## Context
When a truck goes to the shop, the coordinator generates a service brief — a single document with everything the mechanic needs. The mechanic does NOT get access to our agent or fleet data. They get this document.

## Prerequisites
- Which vehicle, which service center, and what service is requested
- If a recommendation was already drafted, use that context

## Workflow

1. Call `vehicle_health_summary` for the vehicle
2. Read `gotchas.md`
3. Read `report-styles/assets/base-layout.html` and `report-styles/assets/shared-styles.css`
4. Copy `templates/service-brief.html`, fill in with vehicle data
5. Write to `/tmp/fleetops-reports/service-brief-{unit_number}-{date}.html`
6. Open in browser
7. Mock-email: log to console AND to `/tmp/fleetops-audit/events.jsonl`:
```bash
mkdir -p /tmp/fleetops-audit
echo '{"type":"service_brief","vehicle":"{unit_number}","recipient":"{contact_email}","ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","sid":"'${CLAUDE_SESSION_ID:-unknown}'"}' >> /tmp/fleetops-audit/events.jsonl
echo "Service brief sent to {contact_email}"
```
