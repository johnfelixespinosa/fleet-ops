---
name: find-maintenance-opportunities
description: Use when asked about vehicles due for maintenance, upcoming service needs, or fleet maintenance scheduling. Runs a multi-step investigation and outputs a Maintenance Investigation Report HTML page.
---

# Find Maintenance Opportunities

## Workflow

1. Call `vehicles_due_for_maintenance` with the requested time window
2. For each flagged vehicle, call `upcoming_trips_for_vehicle` to understand scheduling impact
3. For vehicles with upcoming trips, call `service_centers_near_route` (leg: "return") to find low-disruption service options
4. Rank opportunities by: miles remaining to threshold, number of affected trips, proximity of service centers to routes
5. Read `gotchas.md` before generating output
6. Read `report-styles/assets/base-layout.html` and `report-styles/assets/shared-styles.css`
7. Copy `templates/investigation-report.html`, fill in with investigation data
8. Write to `/tmp/fleetops-reports/maintenance-investigation-{date}.html`
9. Open in browser: `open /tmp/fleetops-reports/maintenance-investigation-{date}.html`
