return if Rails.env.production?
puts "Seeding fleet data..."

# ---------------------------------------------------------------------------
# TimelineBuilder — walk forward from acquisition, accumulating mileage
# ---------------------------------------------------------------------------
module TimelineBuilder
  module_function

  def build_trips_for(vehicle, routes:, start_date:, end_date:, trip_counter:)
    trips = []
    current_date = start_date
    route_index = 0

    while current_date <= end_date
      # 5 route days, 1 light, 1 rest per week
      day_of_week = current_date.wday
      next (current_date += 1.day) if [0, 6].include?(day_of_week) # rest on weekends

      route = routes[route_index % routes.length]
      route_index += 1

      kwh_per_mile = KWH_PER_MILE.fetch(vehicle.make, 1.85)
      # Add ±5% variance per trip for realism
      kwh_per_mile *= (0.95 + rand * 0.10)
      energy = (route[:distance] * kwh_per_mile).round(1)
      departed = current_date <= Date.current

      trip = Trip.create!(
        vehicle: vehicle,
        trip_number: "TRP-%04d" % trip_counter.call,
        origin: route[:origin],
        destination: route[:destination],
        distance_miles: route[:distance],
        cargo_weight_lbs: rand(35_000..42_000),
        departure_at: current_date.to_datetime + 5.hours,  # 05:00 departure
        return_at: current_date.to_datetime + 14.hours,    # 14:00 return
        status: departed ? "completed" : "scheduled",
        energy_consumed_kwh: departed ? energy : nil,
        route_waypoints: route[:waypoints]
      )
      trips << trip
      current_date += 1.day
    end
    trips
  end

  def build_charging_for(vehicle, trip, depot_name:)
    events = []

    # Depot charge the night before (overnight)
    # California commercial TOU rate: $0.12-$0.18/kWh off-peak
    energy_kwh = rand(250..450)
    depot_rate = rand(0.12..0.18)
    events << ChargingEvent.create!(
      vehicle: vehicle,
      trip: nil,
      location_type: "depot",
      station_name: depot_name,
      latitude: 37.3382,
      longitude: -121.8863,
      energy_added_kwh: energy_kwh,
      charge_rate_kw: rand(50..150),
      duration_minutes: rand(360..600),
      cost: (energy_kwh * depot_rate).round(2),
      charged_at: trip.departure_at - rand(8..12).hours
    )

    # ~25% chance of en-route fast charge
    # California DC fast charging: $0.45-$0.65/kWh
    if rand < 0.25 && trip.route_waypoints.present?
      midpoint = trip.route_waypoints[trip.route_waypoints.length / 2] || {}
      enroute_kwh = rand(80..200)
      enroute_rate = rand(0.45..0.65)
      events << ChargingEvent.create!(
        vehicle: vehicle,
        trip: trip,
        location_type: "en_route",
        station_name: "EA Station #{trip.destination.split.first}",
        latitude: midpoint["lat"] || 36.7,
        longitude: midpoint["lng"] || -120.5,
        energy_added_kwh: enroute_kwh,
        charge_rate_kw: rand(250..750),
        duration_minutes: rand(30..60),
        cost: (enroute_kwh * enroute_rate).round(2),
        charged_at: trip.departure_at + rand(3..5).hours
      )
    end

    events
  end

  def build_maintenance_for(vehicle, service_centers:, mileage_at:, type:, completed_at:)
    schedule = Vehicle::MAINTENANCE_SCHEDULE[type.to_sym]
    center = service_centers.sample

    MaintenanceRecord.create!(
      vehicle: vehicle,
      service_center: center,
      maintenance_type: type.to_s,
      description: maintenance_description(type),
      mileage_at_service: mileage_at,
      cost: rand(schedule[:cost_range]).to_f,
      duration_hours: rand_float(schedule[:duration_hours]),
      completed_at: completed_at
    )
  end

  def maintenance_description(type)
    {
      safety_check: "Tires, brakes visual, lights, battery coolant level check",
      standard_service: "Brake pad measurement, HV cable inspection, cabin air filter, safety items",
      comprehensive_service: "Battery coolant flush, alignment, full diagnostic, DOT inspection items",
      major_overhaul: "Component replacement, thermal management overhaul, major battery diagnostic"
    }[type.to_sym]
  end

  def rand_float(range)
    rand * (range.end - range.begin) + range.begin
  end
end

# ---------------------------------------------------------------------------
# Service Centers (find_or_create_by! for idempotency)
# ---------------------------------------------------------------------------
puts "  Creating service centers..."

service_centers_data = [
  {
    name: "Bay Area Fleet Services", address: "8500 Monterey Rd", city: "Gilroy",
    contact_email: "service@bayareafleet.com", latitude: 37.0058, longitude: -121.5683,
    capabilities: %w[safety_check standard_service comprehensive_service battery_diagnostic],
    is_partner: true, ev_certified: true
  },
  {
    name: "Central Valley Truck Care", address: "1200 9th St", city: "Modesto",
    contact_email: "dispatch@centralvalleytruck.com", latitude: 37.6391, longitude: -120.9969,
    capabilities: %w[safety_check standard_service tire_rotation brake_service],
    is_partner: true, ev_certified: true
  },
  {
    name: "Sacramento EV Service Center", address: "2800 Gateway Oaks Dr", city: "Sacramento",
    contact_email: "service@sacevservice.com", latitude: 38.5816, longitude: -121.4944,
    capabilities: %w[safety_check standard_service comprehensive_service major_overhaul battery_diagnostic],
    is_partner: true, ev_certified: true
  },
  {
    name: "Fresno Fleet Maintenance", address: "4700 E Kings Canyon Rd", city: "Fresno",
    contact_email: "shop@fresnofleet.com", latitude: 36.7378, longitude: -119.7519,
    capabilities: %w[safety_check standard_service comprehensive_service tire_rotation],
    is_partner: true, ev_certified: true
  },
  {
    name: "South Bay Commercial Repair", address: "750 Ridder Park Dr", city: "San Jose",
    contact_email: "service@southbaycommercial.com", latitude: 37.3861, longitude: -121.8966,
    capabilities: %w[safety_check standard_service brake_service tire_rotation],
    is_partner: false, ev_certified: true
  },
  {
    name: "Stockton Heavy Vehicle Service", address: "3200 Navy Dr", city: "Stockton",
    contact_email: "service@stocktonheavy.com", latitude: 37.9577, longitude: -121.2908,
    capabilities: %w[safety_check standard_service comprehensive_service],
    is_partner: true, ev_certified: false
  },
  {
    name: "Bakersfield Fleet Works", address: "5100 District Blvd", city: "Bakersfield",
    contact_email: "service@bakersfieldfleet.com", latitude: 35.3733, longitude: -119.0187,
    capabilities: %w[safety_check standard_service comprehensive_service major_overhaul],
    is_partner: false, ev_certified: true
  }
]

service_centers = service_centers_data.map do |data|
  ServiceCenter.find_or_create_by!(name: data[:name]) do |sc|
    sc.assign_attributes(data)
  end
end

gilroy = service_centers.find { |sc| sc.city == "Gilroy" }
fresno = service_centers.find { |sc| sc.city == "Fresno" }
san_jose = service_centers.find { |sc| sc.city == "San Jose" }

# ---------------------------------------------------------------------------
# Vehicles (find_or_create_by! for idempotency)
# ---------------------------------------------------------------------------
puts "  Creating vehicles..."

vehicles_data = [
  { unit_number: "EV-2301", make: "Tesla", model: "Semi 500", year: 2023, battery_capacity_kwh: 850,
    range_miles: 500, current_mileage: 145_000, battery_health_percent: 92.0,
    next_maintenance_due_mileage: 150_000, next_maintenance_type: "comprehensive_service",
    last_maintenance_date: Date.new(2025, 11, 15), annual_inspection_due: Date.current + 6.days,
    daily_inspection_current: true, status: "active" },

  { unit_number: "EV-2302", make: "Tesla", model: "Semi 500", year: 2023, battery_capacity_kwh: 850,
    range_miles: 500, current_mileage: 138_000, battery_health_percent: 93.0,
    next_maintenance_due_mileage: 150_000, next_maintenance_type: "comprehensive_service",
    last_maintenance_date: Date.new(2025, 12, 1), annual_inspection_due: Date.current + 45.days,
    daily_inspection_current: true, status: "active" },

  { unit_number: "EV-2401", make: "Freightliner", model: "eCascadia", year: 2024, battery_capacity_kwh: 438,
    range_miles: 230, current_mileage: 87_000, battery_health_percent: 96.0,
    next_maintenance_due_mileage: 90_000, next_maintenance_type: "standard_service",
    last_maintenance_date: Date.new(2026, 1, 10), annual_inspection_due: Date.current + 120.days,
    daily_inspection_current: true, status: "active" },

  { unit_number: "EV-2402", make: "Freightliner", model: "eCascadia", year: 2024, battery_capacity_kwh: 438,
    range_miles: 230, current_mileage: 92_000, battery_health_percent: 95.0,
    next_maintenance_due_mileage: 90_000, next_maintenance_type: "standard_service",
    last_maintenance_date: Date.new(2025, 12, 20), annual_inspection_due: Date.current + 90.days,
    daily_inspection_current: false, status: "in_shop" },

  { unit_number: "EV-2403", make: "Freightliner", model: "eCascadia", year: 2024, battery_capacity_kwh: 438,
    range_miles: 230, current_mileage: 78_000, battery_health_percent: 97.0,
    next_maintenance_due_mileage: 90_000, next_maintenance_type: "standard_service",
    last_maintenance_date: Date.new(2026, 1, 25), annual_inspection_due: Date.current + 150.days,
    daily_inspection_current: true, status: "active" },

  { unit_number: "EV-2501", make: "Volvo", model: "VNR Electric", year: 2025, battery_capacity_kwh: 565,
    range_miles: 275, current_mileage: 34_000, battery_health_percent: 99.0,
    next_maintenance_due_mileage: 35_000, next_maintenance_type: "safety_check",
    last_maintenance_date: Date.new(2026, 1, 5), annual_inspection_due: Date.current + 200.days,
    daily_inspection_current: true, status: "active" },

  { unit_number: "EV-2502", make: "Volvo", model: "VNR Electric", year: 2025, battery_capacity_kwh: 565,
    range_miles: 275, current_mileage: 28_000, battery_health_percent: 99.0,
    next_maintenance_due_mileage: 30_000, next_maintenance_type: "safety_check",
    last_maintenance_date: Date.new(2026, 2, 1), annual_inspection_due: Date.current + 210.days,
    daily_inspection_current: true, status: "active" },

  { unit_number: "EV-2503", make: "Tesla", model: "Semi 500", year: 2025, battery_capacity_kwh: 850,
    range_miles: 500, current_mileage: 42_000, battery_health_percent: 98.0,
    next_maintenance_due_mileage: 45_000, next_maintenance_type: "standard_service",
    last_maintenance_date: Date.new(2026, 2, 10), annual_inspection_due: Date.current + 180.days,
    daily_inspection_current: true, status: "active" },

  { unit_number: "EV-2601", make: "Tesla", model: "Semi 500", year: 2026, battery_capacity_kwh: 850,
    range_miles: 500, current_mileage: 5_200, battery_health_percent: 100.0,
    next_maintenance_due_mileage: 10_000, next_maintenance_type: "safety_check",
    last_maintenance_date: nil, annual_inspection_due: Date.current + 300.days,
    daily_inspection_current: true, status: "active" },

  { unit_number: "EV-2602", make: "Freightliner", model: "eCascadia", year: 2026, battery_capacity_kwh: 438,
    range_miles: 230, current_mileage: 3_800, battery_health_percent: 100.0,
    next_maintenance_due_mileage: 10_000, next_maintenance_type: "safety_check",
    last_maintenance_date: nil, annual_inspection_due: Date.current + 310.days,
    daily_inspection_current: true, status: "active" },

  { unit_number: "EV-2603", make: "Volvo", model: "VNR Electric", year: 2026, battery_capacity_kwh: 565,
    range_miles: 275, current_mileage: 8_100, battery_health_percent: 100.0,
    next_maintenance_due_mileage: 10_000, next_maintenance_type: "safety_check",
    last_maintenance_date: nil, annual_inspection_due: Date.current + 280.days,
    daily_inspection_current: true, status: "active" },

  { unit_number: "EV-2604", make: "Tesla", model: "Semi 500", year: 2026, battery_capacity_kwh: 850,
    range_miles: 500, current_mileage: 6_500, battery_health_percent: 100.0,
    next_maintenance_due_mileage: 10_000, next_maintenance_type: "safety_check",
    last_maintenance_date: nil, annual_inspection_due: Date.current + 320.days,
    daily_inspection_current: true, status: "active" }
]

vehicles = vehicles_data.map do |data|
  Vehicle.find_or_create_by!(unit_number: data[:unit_number]) do |v|
    v.assign_attributes(data)
  end
end

vehicles_by_unit = vehicles.index_by(&:unit_number)

# ---------------------------------------------------------------------------
# Route definitions (California regional routes from San Jose hub)
# ---------------------------------------------------------------------------
# kWh/mile rates by make (loaded, real-world data):
#   Tesla Semi: 1.55-1.73 (ArcBest/PepsiCo/DHL tests)
#   eCascadia:  1.90-2.10 (calculated from 438kWh/230mi spec)
#   Volvo VNR:  1.80-2.00 (Volvo FH test proxy + specs)
KWH_PER_MILE = {
  "Tesla" => 1.65,
  "Freightliner" => 2.0,
  "Volvo" => 1.85
}.freeze

# Route distances are ROUND TRIP (real-world driving distances)
ROUTES = {
  sj_fresno: {
    origin: "San Jose Distribution Center", destination: "Fresno Regional Hub",
    distance: 304, # 152 mi one-way via CA-152/CA-99
    waypoints: [
      { lat: 37.3382, lng: -121.8863 }, { lat: 37.0058, lng: -121.5683 },
      { lat: 36.8400, lng: -120.8900 }, { lat: 36.7378, lng: -119.7871 }
    ]
  },
  sj_sacramento: {
    origin: "San Jose Distribution Center", destination: "Sacramento Depot",
    distance: 242, # 121 mi one-way via I-680/I-80
    waypoints: [
      { lat: 37.3382, lng: -121.8863 }, { lat: 37.6391, lng: -121.0000 },
      { lat: 37.9577, lng: -121.2908 }, { lat: 38.5816, lng: -121.4944 }
    ]
  },
  sj_modesto: {
    origin: "San Jose Distribution Center", destination: "Modesto Warehouse",
    distance: 182, # 91 mi one-way via CA-132
    waypoints: [
      { lat: 37.3382, lng: -121.8863 }, { lat: 37.4600, lng: -121.4500 },
      { lat: 37.6391, lng: -120.9969 }
    ]
  },
  sj_stockton: {
    origin: "San Jose Distribution Center", destination: "Stockton Distribution Center",
    distance: 168, # 84 mi one-way via I-580/I-5
    waypoints: [
      { lat: 37.3382, lng: -121.8863 }, { lat: 37.6800, lng: -121.3500 },
      { lat: 37.9577, lng: -121.2908 }
    ]
  },
  sj_bakersfield: {
    origin: "San Jose Distribution Center", destination: "Bakersfield Logistics Park",
    distance: 482, # 241 mi one-way via I-5 — Tesla Semi only (requires 500mi range)
    waypoints: [
      { lat: 37.3382, lng: -121.8863 }, { lat: 36.7378, lng: -119.7871 },
      { lat: 35.8200, lng: -119.3500 }, { lat: 35.3733, lng: -119.0187 }
    ]
  }
}.freeze

# ---------------------------------------------------------------------------
# Trips, Maintenance Records, and Charging Events (guarded by count check)
# ---------------------------------------------------------------------------
if Trip.count == 0
  puts "  Generating trips, maintenance records, and charging events..."

  trip_number = 460
  trip_counter = -> { trip_number += 1; trip_number - 1 }

  # ----- EV-2501 (demo-critical): Thursday trip San Jose -> Fresno -----
  ev2501 = vehicles_by_unit["EV-2501"]

  # Past trips (last 30 days) — Volvo VNR range 275mi, use shorter routes
  past_trips_2501 = TimelineBuilder.build_trips_for(
    ev2501,
    routes: [ROUTES[:sj_modesto], ROUTES[:sj_stockton], ROUTES[:sj_sacramento]],
    start_date: 30.days.ago.to_date,
    end_date: Date.yesterday,
    trip_counter: trip_counter
  )

  # Thursday trip (the demo scenario) — San Jose -> Fresno
  next_thursday = Date.current
  next_thursday += 1.day until next_thursday.thursday?

  Trip.create!(
    vehicle: ev2501,
    trip_number: "TRP-%04d" % trip_counter.call,
    origin: "San Jose Distribution Center",
    destination: "Fresno Regional Hub",
    distance_miles: 304, # 152 mi one-way, real SJ->Fresno RT
    cargo_weight_lbs: 38_500,
    departure_at: next_thursday.to_datetime + 5.hours,
    return_at: next_thursday.to_datetime + 14.hours,
    status: "scheduled",
    energy_consumed_kwh: nil,
    route_waypoints: ROUTES[:sj_fresno][:waypoints]
  )

  # EV-2501 maintenance history — last safety_check at 20,000 mi
  TimelineBuilder.build_maintenance_for(
    ev2501, service_centers: [san_jose], mileage_at: 5_000,
    type: :safety_check, completed_at: Date.new(2025, 4, 15).to_datetime
  )
  TimelineBuilder.build_maintenance_for(
    ev2501, service_centers: [gilroy], mileage_at: 20_000,
    type: :safety_check, completed_at: Date.new(2025, 9, 20).to_datetime
  )

  # Charging events for past trips
  past_trips_2501.select(&:completed?).each do |trip|
    TimelineBuilder.build_charging_for(ev2501, trip, depot_name: "SJ Depot Charger Bay 3")
  end

  # ----- EV-2301 (demo-critical): High mileage, annual inspection due -----
  ev2301 = vehicles_by_unit["EV-2301"]

  past_trips_2301 = TimelineBuilder.build_trips_for(
    ev2301,
    routes: [ROUTES[:sj_sacramento], ROUTES[:sj_bakersfield], ROUTES[:sj_fresno]],
    start_date: 30.days.ago.to_date,
    end_date: Date.current + 7.days,
    trip_counter: trip_counter
  )

  # EV-2301 extensive maintenance history
  [
    { mileage: 15_000, type: :safety_check, date: Date.new(2023, 9, 1) },
    { mileage: 30_000, type: :standard_service, date: Date.new(2024, 1, 15) },
    { mileage: 45_000, type: :safety_check, date: Date.new(2024, 5, 10) },
    { mileage: 60_000, type: :comprehensive_service, date: Date.new(2024, 8, 20) },
    { mileage: 75_000, type: :safety_check, date: Date.new(2024, 12, 5) },
    { mileage: 90_000, type: :standard_service, date: Date.new(2025, 3, 15) },
    { mileage: 100_000, type: :major_overhaul, date: Date.new(2025, 6, 1) },
    { mileage: 115_000, type: :safety_check, date: Date.new(2025, 8, 25) },
    { mileage: 130_000, type: :standard_service, date: Date.new(2025, 11, 15) }
  ].each do |m|
    TimelineBuilder.build_maintenance_for(
      ev2301, service_centers: service_centers, mileage_at: m[:mileage],
      type: m[:type], completed_at: m[:date].to_datetime
    )
  end

  past_trips_2301.select(&:completed?).each do |trip|
    TimelineBuilder.build_charging_for(ev2301, trip, depot_name: "SJ Depot Charger Bay 1")
  end

  # ----- EV-2403 (demo-critical): Battery health declining -----
  ev2403 = vehicles_by_unit["EV-2403"]

  # eCascadia range: 230mi — only Modesto (182 RT) and Stockton (168 RT)
  past_trips_2403 = TimelineBuilder.build_trips_for(
    ev2403,
    routes: [ROUTES[:sj_modesto], ROUTES[:sj_stockton]],
    start_date: 30.days.ago.to_date,
    end_date: Date.current + 7.days,
    trip_counter: trip_counter
  )

  [
    { mileage: 15_000, type: :safety_check, date: Date.new(2024, 7, 10) },
    { mileage: 30_000, type: :standard_service, date: Date.new(2024, 11, 5) },
    { mileage: 45_000, type: :safety_check, date: Date.new(2025, 3, 20) },
    { mileage: 60_000, type: :comprehensive_service, date: Date.new(2025, 7, 15) },
    { mileage: 75_000, type: :safety_check, date: Date.new(2026, 1, 25) }
  ].each do |m|
    TimelineBuilder.build_maintenance_for(
      ev2403, service_centers: service_centers, mileage_at: m[:mileage],
      type: m[:type], completed_at: m[:date].to_datetime
    )
  end

  past_trips_2403.select(&:completed?).each do |trip|
    TimelineBuilder.build_charging_for(ev2403, trip, depot_name: "SJ Depot Charger Bay 5")
  end

  # ----- Remaining vehicles: generic timeline patterns -----
  generic_vehicles = %w[EV-2302 EV-2401 EV-2402 EV-2502 EV-2503 EV-2601 EV-2602 EV-2603 EV-2604]

  # Route assignment respects vehicle range
  # eCascadia (230mi): Stockton (168), Modesto (182) only
  # Volvo VNR (275mi): Stockton (168), Modesto (182), Sacramento (242)
  # Tesla Semi (500mi): all routes including Fresno (304) and Bakersfield (482)
  short_routes = [ROUTES[:sj_stockton], ROUTES[:sj_modesto]]
  medium_routes = short_routes + [ROUTES[:sj_sacramento]]
  long_routes = medium_routes + [ROUTES[:sj_fresno], ROUTES[:sj_bakersfield]]

  generic_vehicles.each do |unit|
    vehicle = vehicles_by_unit[unit]
    next unless vehicle

    route_pool = case vehicle.make
    when "Freightliner" then short_routes
    when "Volvo" then medium_routes
    else long_routes
    end
    routes = route_pool.sample([3, route_pool.size].min)
    start_date = vehicle.status == "in_shop" ? 30.days.ago.to_date : 14.days.ago.to_date
    end_date = vehicle.status == "in_shop" ? 5.days.ago.to_date : Date.current + 5.days

    trips = TimelineBuilder.build_trips_for(
      vehicle,
      routes: routes,
      start_date: start_date,
      end_date: end_date,
      trip_counter: trip_counter
    )

    # Maintenance history based on current mileage
    if vehicle.current_mileage > 15_000
      TimelineBuilder.build_maintenance_for(
        vehicle, service_centers: service_centers, mileage_at: 10_000,
        type: :safety_check, completed_at: 6.months.ago.to_datetime
      )
    end
    if vehicle.current_mileage > 30_000
      TimelineBuilder.build_maintenance_for(
        vehicle, service_centers: service_centers, mileage_at: 30_000,
        type: :standard_service, completed_at: 4.months.ago.to_datetime
      )
    end
    if vehicle.current_mileage > 60_000
      TimelineBuilder.build_maintenance_for(
        vehicle, service_centers: service_centers, mileage_at: 60_000,
        type: :comprehensive_service, completed_at: 3.months.ago.to_datetime
      )
    end
    if vehicle.current_mileage > 100_000
      TimelineBuilder.build_maintenance_for(
        vehicle, service_centers: service_centers, mileage_at: 100_000,
        type: :major_overhaul, completed_at: 2.months.ago.to_datetime
      )
    end

    trips.select(&:completed?).each do |trip|
      bay = "SJ Depot Charger Bay #{rand(1..8)}"
      TimelineBuilder.build_charging_for(vehicle, trip, depot_name: bay)
    end
  end
end

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
puts ""
puts "Seed complete!"
puts "  Vehicles:           #{Vehicle.count}"
puts "  Service Centers:    #{ServiceCenter.count}"
puts "  Trips:              #{Trip.count}"
puts "  Maintenance Records:#{MaintenanceRecord.count}"
puts "  Charging Events:    #{ChargingEvent.count}"
puts "  Copilot Sessions:   #{CopilotSession.count}"
