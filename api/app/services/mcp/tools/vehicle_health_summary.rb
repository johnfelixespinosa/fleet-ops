module Mcp
  module Tools
    class VehicleHealthSummary
      def self.tool_name = "vehicle_health_summary"

      def self.description
        "Get a comprehensive health summary for a specific vehicle including efficiency trends, " \
        "charging patterns, maintenance history, and utilization stats."
      end

      def self.input_schema
        {
          type: "object",
          properties: {
            vehicle_id: { type: "string", description: "UUID of the vehicle" }
          },
          required: ["vehicle_id"]
        }
      end

      def self.execute(params)
        v = Vehicle.find(params["vehicle_id"])
        recent_trips = v.trips.where(status: "completed").order(return_at: :desc).limit(10)
        recent_charging = v.charging_events.order(charged_at: :desc).limit(10)
        maintenance_history = v.maintenance_records.order(completed_at: :desc).limit(5)

        efficiency_trend = recent_trips.filter_map do |t|
          next unless t.energy_consumed_kwh&.positive? && t.distance_miles&.positive?
          {
            trip_number: t.trip_number,
            date: t.return_at.to_date.iso8601,
            kwh_per_mile: (t.energy_consumed_kwh / t.distance_miles).round(3),
            distance_miles: t.distance_miles,
            cargo_weight_lbs: t.cargo_weight_lbs
          }
        end

        depot_charges = recent_charging.select { |c| c.location_type == "depot" }
        enroute_charges = recent_charging.select { |c| c.location_type == "en_route" }

        {
          unit_number: v.unit_number,
          make_model: "#{v.year} #{v.make} #{v.model}",
          current_mileage: v.current_mileage,
          battery_health_percent: v.battery_health_percent,
          battery_capacity_kwh: v.battery_capacity_kwh,
          status: v.status,
          efficiency_trend: efficiency_trend,
          avg_kwh_per_mile: efficiency_trend.any? ? (efficiency_trend.sum { |e| e[:kwh_per_mile] } / efficiency_trend.size).round(3) : nil,
          charging_summary: {
            depot_charges_last_10: depot_charges.size,
            enroute_charges_last_10: enroute_charges.size,
            avg_depot_kwh: depot_charges.any? ? (depot_charges.sum(&:energy_added_kwh) / depot_charges.size).round(1) : nil,
            avg_enroute_kwh: enroute_charges.any? ? (enroute_charges.sum(&:energy_added_kwh) / enroute_charges.size).round(1) : nil
          },
          recent_maintenance: maintenance_history.map { |m|
            { type: m.maintenance_type, date: m.completed_at.to_date.iso8601, mileage: m.mileage_at_service, cost: m.cost }
          },
          next_maintenance: {
            type: v.next_maintenance_type,
            due_at_mileage: v.next_maintenance_due_mileage,
            miles_remaining: v.next_maintenance_due_mileage - v.current_mileage
          },
          annual_inspection_due: v.annual_inspection_due&.iso8601
        }
      end
    end
  end
end
