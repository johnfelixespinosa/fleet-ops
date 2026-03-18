# Gotchas

- The mechanic is NOT an employee — never include fleet-wide data, trip schedules, or other vehicles
- Only include information about the SPECIFIC vehicle being serviced
- Always include the EV safety reminder — mechanics may not be used to high-voltage systems
- VIN field: use "N/A — see physical vehicle" for the demo (we don't have VINs in seed data)
- If battery health is below 95% or efficiency is trending up, include it in Known Issues even if the current service request is unrelated — the mechanic should know
- Cost estimates in the service brief are for the SERVICE CENTER's reference, not the fleet's internal cost tracking
