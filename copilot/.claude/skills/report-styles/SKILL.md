---
name: report-styles
description: Shared CSS and HTML base layout for all FleetOps Copilot reports. Other skills reference these assets when generating output.
---

# FleetOps Copilot Report Styles

This skill contains the shared visual assets for all reports. When generating any HTML report:

1. Read `assets/base-layout.html` for the HTML structure
2. Read `assets/shared-styles.css` for the CSS
3. Copy the base layout, inject the CSS into the `<style>` tag
4. Fill in the report-specific content in the `<main>` section

All reports are written to `/tmp/fleetops-reports/`. Create the directory if needed:
```bash
mkdir -p /tmp/fleetops-reports
```

After writing the HTML file, open it:
```bash
open /tmp/fleetops-reports/{filename}.html
```
