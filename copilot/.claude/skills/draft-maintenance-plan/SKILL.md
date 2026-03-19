---
name: draft-maintenance-plan
description: Use after investigating maintenance opportunities, when ready to generate a formal recommendation. Creates an HTML report AND a git PR for fleet manager approval.
---

# Draft Maintenance Plan

## Prerequisites
- You MUST have run find-maintenance-opportunities first
- You MUST have identified a specific vehicle, service center, and trip

## Workflow

1. Call `draft_maintenance_recommendation` with the vehicle, service center, and trip
2. Read `report-styles/assets/base-layout.html` and `report-styles/assets/shared-styles.css`
3. Copy `templates/recommendation-report.html`, fill in with recommendation data
4. Write HTML to `/tmp/fleetops-reports/recommendation-{unit_number}-{date}-{unique6}.html`
5. Open in browser
6. Copy `templates/recommendation.md`, fill in with the same data
7. Write markdown to `recommendations/{unit_number}-{date}-{maintenance_type}.md`
8. Create git branch: `recommendations/{unit_number}-{date}-{maintenance_type}`
9. Commit the recommendation file
10. Create PR: `gh pr create --title "Maintenance: {unit_number} {maintenance_type} at {service_center}"`
11. Report the PR URL back to the user
