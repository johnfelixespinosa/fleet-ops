---
vehicle_unit: "EV-2401"
vehicle_id: "857a0d2f-700f-4985-9673-fa515960d4af"
service_center: "Central Valley Truck Care"
service_center_id: "83eb7e21-70d5-478a-b1ac-72f820bcd51f"
trip_id: "9700a90e-3a01-4cb8-aed3-f8ba7e0d7409"
window: "2026-03-20 (during TRP-0564 Modesto run)"
urgency: moderate
status: proposed
generated_by: "FleetOps Copilot"
---

## Recommendation
Schedule EV-2401 for a **standard service** at **Central Valley Truck Care** (Modesto) during trip **TRP-0564** on **March 20, 2026**. The service center is directly on the return route (0 miles off-route), and the truck is 3,000 miles from its 90,000-mile service threshold. Standard service takes 3–5 hours and fits within the trip's 9-hour window.

## Evidence
- EV-2401 is at 87,000 miles; standard service threshold is 90,000 miles (3,000 miles remaining)
- Central Valley Truck Care is EV-certified and located on the return leg of the Modesto route
- TRP-0564 departs March 20 at 5:00 AM, returns by 2:00 PM — sufficient window for service
- Battery health at 96.0% — normal for a 2024 Freightliner eCascadia
- Cost estimate: $400–$800 for standard service

## Affected Trips
- **TRP-0565** — Stockton Distribution Center, March 23, 2026
- **TRP-0566** — Modesto Warehouse, March 24, 2026

These trips may need schedule adjustment if service extends beyond the return window on March 20.

## Assumptions
- Service center availability not confirmed — recommend calling ahead
- Duration estimate based on standard service (~3–5 hours)
- No technician load or bay capacity data available
- Cost estimate: $400–$800

## Tool Calls
- `fleet_query(vehicle_by_unit:EV-2401)` — vehicle lookup
- `upcoming_trips_for_vehicle(857a0d2f-700f-4985-9673-fa515960d4af)` — trip schedule
- `service_centers_near_route(TRP-0564, TRP-0565, TRP-0566)` — service center search
- `draft_maintenance_recommendation(EV-2401, Central Valley Truck Care, TRP-0564)` — recommendation generation
