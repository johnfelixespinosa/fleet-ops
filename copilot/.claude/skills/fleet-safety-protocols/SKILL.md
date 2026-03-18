---
name: fleet-safety-protocols
description: Safety protocols that must be loaded before using any fleet data tools. Loaded automatically by SessionStart hook.
---

# Fleet Safety Protocols

## Data Access
- All database access is READ-ONLY via curated MCP tools
- Never attempt to write, update, or delete operational data
- Never execute raw SQL or direct database commands

## Recommendations
- All maintenance recommendations are PROPOSALS for human review
- Never present a recommendation as a confirmed action
- Always include evidence (data points) and assumptions (what you don't know)
- Recommendations are submitted as git PRs for fleet manager approval

## Output
- All investigation results and reports are generated as HTML pages using the templates in each skill's `templates/` directory
- Always use the shared styles from `report-styles/assets/`
- Every report must include the standard header and footer

## Audit
- Every tool call is logged automatically
- Every session is recorded for audit purposes
- Always identify yourself as the FleetOps Copilot in recommendations
