# Gotchas

- Do NOT flag vehicles with status `in_shop` or `out_of_service` — they're already being handled
- Do NOT assume service center availability — always list as "not confirmed"
- Always state what data you lack: technician load, bay capacity, parts availability
- If a vehicle has no recent trips (no mileage data), say "insufficient data to project threshold date" rather than guessing
- Urgency classification: critical = will exceed threshold before next scheduled trip, high = within 1,000 miles, moderate = within 5,000 miles
- A vehicle can have BOTH a maintenance threshold approaching AND an annual inspection due — flag both
