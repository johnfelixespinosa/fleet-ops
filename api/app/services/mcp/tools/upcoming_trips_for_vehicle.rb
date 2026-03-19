module Mcp
  module Tools
    class UpcomingTripsForVehicle
      def self.tool_name = "upcoming_trips_for_vehicle"

      def self.description
        "Get scheduled trips for a specific vehicle within a given number of days ahead."
      end

      def self.input_schema
        {
          type: "object",
          properties: {
            vehicle_id: { type: "string", description: "UUID of the vehicle" },
            days_ahead: { type: "integer", description: "Number of days to look ahead (default: 14)", default: 14 }
          },
          required: ["vehicle_id"]
        }
      end

      def self.execute(params)
        vehicle = Vehicle.find(params["vehicle_id"])
        days = (params["days_ahead"] || 14).to_i
        trips = vehicle.trips.upcoming(days).order(:departure_at)

        trips.map do |t|
          {
            trip_id: t.id,
            trip_number: t.trip_number,
            origin: t.origin,
            destination: t.destination,
            distance_miles: t.distance_miles,
            cargo_weight_lbs: t.cargo_weight_lbs,
            departure_at: t.departure_at.iso8601,
            return_at: t.return_at.iso8601,
            has_waypoints: t.route_waypoints.present?
          }
        end
      end

      def self.summary(results, params)
        vehicle = Vehicle.find_by(id: params["vehicle_id"])
        unit = vehicle&.unit_number || "Unknown"
        days = params["days_ahead"] || 14
        if results.empty?
          "No scheduled trips found for #{unit} in the next #{days} days."
        else
          routes = results.map { |t| "#{t[:trip_number]} to #{t[:destination]} (#{t[:distance_miles]} mi)" }.join("; ")
          "Found #{results.size} upcoming trip#{"s" if results.size > 1} for #{unit}: #{routes}"
        end
      end
    end
  end
end
