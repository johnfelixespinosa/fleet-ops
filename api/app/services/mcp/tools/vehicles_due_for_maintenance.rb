module Mcp
  module Tools
    class VehiclesDueForMaintenance
      def self.tool_name = "vehicles_due_for_maintenance"

      def self.description
        "Find vehicles approaching or past their maintenance threshold within a given number of days. " \
        "Estimates daily mileage from recent trips and projects when each vehicle will reach its threshold."
      end

      def self.input_schema
        {
          type: "object",
          properties: {
            within_days: { type: "integer", description: "Number of days to look ahead (default: 7)", default: 7 }
          }
        }
      end

      def self.execute(params)
        within_days = params["within_days"] || 7
        vehicles = Vehicle.active

        results = vehicles.filter_map do |v|
          recent_trips = v.trips.where(status: "completed").where("return_at > ?", 30.days.ago)
          daily_miles = if recent_trips.any?
            total_miles = recent_trips.sum(:distance_miles)
            days = [(recent_trips.maximum(:return_at).to_date - recent_trips.minimum(:departure_at).to_date).to_i, 1].max
            (total_miles.to_f / days).round(1)
          else
            0
          end

          projected_mileage = v.current_mileage + (daily_miles * within_days)
          miles_to_threshold = v.next_maintenance_due_mileage - v.current_mileage

          if projected_mileage >= v.next_maintenance_due_mileage || miles_to_threshold <= 1000
            {
              unit_number: v.unit_number,
              vehicle_id: v.id,
              make_model: "#{v.year} #{v.make} #{v.model}",
              current_mileage: v.current_mileage,
              threshold_mileage: v.next_maintenance_due_mileage,
              miles_remaining: miles_to_threshold,
              maintenance_type: v.next_maintenance_type,
              daily_mileage_estimate: daily_miles,
              projected_days_until_due: daily_miles > 0 ? (miles_to_threshold / daily_miles).round(1) : nil,
              annual_inspection_due: v.annual_inspection_due&.iso8601,
              battery_health_percent: v.battery_health_percent
            }
          end
        end

        results.sort_by { |r| r[:miles_remaining] }
      end
    end
  end
end
