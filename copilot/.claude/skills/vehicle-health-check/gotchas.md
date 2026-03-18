# Gotchas

- kWh/mile benchmarks differ BY MODEL — never compare across models:
  - Tesla Semi: 1.55–1.73 kWh/mile
  - Freightliner eCascadia: 1.9–2.1 kWh/mile
  - Volvo VNR Electric: 1.8–2.0 kWh/mile
- Battery health below 95% before 50,000 miles IS unusual and warrants investigation
- Normal degradation is ~2% per year. Faster than that → flag it
- Cargo weight affects efficiency — a trip at 42,000 lbs will show higher kWh/mile than 35,000 lbs. Don't compare loaded vs empty trips
- DC fast charging (en_route) above 50% of total charges correlates with accelerated degradation
- Classification guide:
  - normal: all metrics within expected ranges
  - monitor: one metric slightly outside range, no immediate action needed
  - investigate: efficiency declining or battery health below expected, recommend diagnostic
  - urgent: multiple metrics outside range, or safety-related concern
