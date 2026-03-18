---
name: vehicle-health-check
description: Use when asked about a specific vehicle's health, efficiency, battery condition, or whether anomalies are worth investigating. Outputs a Vehicle Health Report HTML page.
---

# Vehicle Health Check

## Workflow

1. Call `vehicle_health_summary` for the target vehicle
2. Analyze efficiency trend (kWh/mile) — read gotchas.md for model-specific benchmarks
3. Review battery health vs expected degradation (~2% per year is normal)
4. Check charging patterns — high DC fast charge ratio accelerates degradation
5. Review maintenance history
6. Classify: normal / monitor / investigate / urgent
7. Read `report-styles/assets/base-layout.html` and `report-styles/assets/shared-styles.css`
8. Copy `templates/health-report.html`, fill in with analysis data
9. Write to `/tmp/fleetops-reports/vehicle-health-{unit_number}-{date}.html`
10. Open in browser
