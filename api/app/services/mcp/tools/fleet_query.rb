module Mcp
  module Tools
    class FleetQuery
      def self.tool_name = "fleet_query"

      def self.description
        "Query fleet data directly. Use this for any question the other tools can't answer — " \
        "looking up vehicles, trips, service centers, maintenance records, or charging events. " \
        "Data models: Vehicle (unit_number, make, model, year, status, current_mileage, " \
        "battery_capacity_kwh, range_miles, battery_health_percent, next_maintenance_type, " \
        "next_maintenance_due_mileage, last_maintenance_date, annual_inspection_due). " \
        "Trip (trip_number, vehicle, origin, destination, distance_miles, cargo_weight_lbs, " \
        "departure_at, return_at, status, energy_consumed_kwh). " \
        "ServiceCenter (name, city, address, contact_email, is_partner, ev_certified, capabilities, latitude, longitude). " \
        "MaintenanceRecord (vehicle, service_center, maintenance_type, mileage_at_service, cost, duration_hours, completed_at). " \
        "ChargingEvent (vehicle, trip, location_type, station_name, energy_added_kwh, charge_rate_kw, duration_minutes, cost, charged_at)."
      end

      def self.input_schema
        {
          type: "object",
          properties: {
            query: {
              type: "string",
              description: "What to look up. Examples: 'all_vehicles', 'vehicle_by_unit:EV-2601', " \
                "'trips_for_unit:EV-2601', 'next_trip_for_unit:EV-2601', 'vehicle_count', " \
                "'all_service_centers', 'service_center_by_city:Gilroy', 'ev_certified_centers', " \
                "'partner_centers', 'trips_on_date:2026-03-20', 'search_trips:Fresno', " \
                "'maintenance_history:EV-2501', 'charging_history:EV-2501'"
            }
          },
          required: ["query"]
        }
      end

      QUERIES = {
        "all_vehicles" => ->(_) {
          Vehicle.order(:unit_number).map { |v|
            { unit_number: v.unit_number, make: v.make, model: v.model, year: v.year,
              status: v.status, current_mileage: v.current_mileage,
              battery_health_percent: v.battery_health_percent,
              next_maintenance_type: v.next_maintenance_type,
              miles_to_maintenance: v.miles_to_maintenance }
          }
        },
        "vehicle_by_unit" => ->(param) {
          v = Vehicle.find_by!(unit_number: param.upcase)
          { id: v.id, unit_number: v.unit_number, make: v.make, model: v.model, year: v.year,
            status: v.status, current_mileage: v.current_mileage,
            battery_capacity_kwh: v.battery_capacity_kwh, range_miles: v.range_miles,
            battery_health_percent: v.battery_health_percent,
            next_maintenance_type: v.next_maintenance_type,
            next_maintenance_due_mileage: v.next_maintenance_due_mileage,
            miles_to_maintenance: v.miles_to_maintenance,
            last_maintenance_date: v.last_maintenance_date&.iso8601,
            annual_inspection_due: v.annual_inspection_due&.iso8601,
            daily_inspection_current: v.daily_inspection_current }
        },
        "trips_for_unit" => ->(param) {
          v = Vehicle.find_by!(unit_number: param.upcase)
          v.trips.order(:departure_at).limit(20).map { |t|
            { trip_number: t.trip_number, origin: t.origin, destination: t.destination,
              distance_miles: t.distance_miles, cargo_weight_lbs: t.cargo_weight_lbs,
              departure_at: t.departure_at.iso8601, status: t.status,
              energy_consumed_kwh: t.energy_consumed_kwh }
          }
        },
        "next_trip_for_unit" => ->(param) {
          v = Vehicle.find_by!(unit_number: param.upcase)
          t = v.trips.scheduled.order(:departure_at).first
          if t
            { trip_number: t.trip_number, origin: t.origin, destination: t.destination,
              distance_miles: t.distance_miles, cargo_weight_lbs: t.cargo_weight_lbs,
              departure_at: t.departure_at.iso8601, return_at: t.return_at.iso8601 }
          else
            { message: "No scheduled trips found for #{param.upcase}" }
          end
        },
        "vehicle_count" => ->(_) { { total: Vehicle.count, active: Vehicle.active.count, in_shop: Vehicle.in_shop.count } },
        "all_service_centers" => ->(_) {
          ServiceCenter.order(:name).map { |sc|
            { id: sc.id, name: sc.name, city: sc.city, address: sc.address,
              contact_email: sc.contact_email, is_partner: sc.is_partner,
              ev_certified: sc.ev_certified, capabilities: sc.capabilities,
              latitude: sc.latitude, longitude: sc.longitude }
          }
        },
        "service_center_by_city" => ->(param) {
          centers = ServiceCenter.where("city ILIKE ?", "%#{param}%").order(:name)
          centers.map { |sc|
            { id: sc.id, name: sc.name, city: sc.city, address: sc.address,
              contact_email: sc.contact_email, is_partner: sc.is_partner,
              ev_certified: sc.ev_certified, capabilities: sc.capabilities }
          }
        },
        "ev_certified_centers" => ->(_) {
          ServiceCenter.ev_certified.order(:name).map { |sc|
            { id: sc.id, name: sc.name, city: sc.city, contact_email: sc.contact_email,
              ev_certified: true, is_partner: sc.is_partner, capabilities: sc.capabilities }
          }
        },
        "partner_centers" => ->(_) {
          ServiceCenter.partners.order(:name).map { |sc|
            { id: sc.id, name: sc.name, city: sc.city, contact_email: sc.contact_email,
              is_partner: true, ev_certified: sc.ev_certified, capabilities: sc.capabilities }
          }
        },
        "trips_on_date" => ->(param) {
          date = Date.parse(param)
          Trip.where(departure_at: date.beginning_of_day..date.end_of_day).order(:departure_at).map { |t|
            { trip_number: t.trip_number, vehicle: t.vehicle.unit_number,
              origin: t.origin, destination: t.destination,
              distance_miles: t.distance_miles, status: t.status,
              departure_at: t.departure_at.iso8601 }
          }
        },
        "search_trips" => ->(param) {
          Trip.where("origin ILIKE ? OR destination ILIKE ?", "%#{param}%", "%#{param}%")
              .order(:departure_at).limit(20).map { |t|
            { trip_number: t.trip_number, vehicle: t.vehicle.unit_number,
              origin: t.origin, destination: t.destination,
              distance_miles: t.distance_miles, status: t.status,
              departure_at: t.departure_at.iso8601 }
          }
        },
        "maintenance_history" => ->(param) {
          v = Vehicle.find_by!(unit_number: param.upcase)
          v.maintenance_records.recent.limit(10).map { |m|
            { maintenance_type: m.maintenance_type, mileage_at_service: m.mileage_at_service,
              cost: m.cost, duration_hours: m.duration_hours,
              service_center: m.service_center.name, completed_at: m.completed_at.iso8601 }
          }
        },
        "charging_history" => ->(param) {
          v = Vehicle.find_by!(unit_number: param.upcase)
          v.charging_events.recent.limit(10).map { |e|
            { location_type: e.location_type, station_name: e.station_name,
              energy_added_kwh: e.energy_added_kwh, charge_rate_kw: e.charge_rate_kw,
              duration_minutes: e.duration_minutes, cost: e.cost,
              charged_at: e.charged_at.iso8601 }
          }
        }
      }.freeze

      def self.execute(params)
        raw = params["query"].to_s.strip
        query_type, param = raw.split(":", 2)
        query_type = query_type.strip.downcase

        handler = QUERIES[query_type]
        return { error: "Unknown query: #{query_type}", available: QUERIES.keys } unless handler

        handler.call(param&.strip)
      end

      def self.summary(result, params)
        query = params["query"].to_s
        if result.is_a?(Array)
          "Fleet query '#{query}': #{result.size} result#{"s" if result.size != 1}"
        elsif result.is_a?(Hash) && result[:error]
          "Fleet query '#{query}': #{result[:error]}"
        else
          "Fleet query '#{query}': found"
        end
      end
    end
  end
end
