module Mcp
  module Tools
    class DraftMaintenanceRecommendation
      def self.tool_name = "draft_maintenance_recommendation"

      def self.description
        "Generate a structured maintenance recommendation with evidence, affected trips, " \
        "suggested window, and assumptions. Returns data suitable for creating a recommendation artifact."
      end

      def self.input_schema
        {
          type: "object",
          properties: {
            vehicle_id: { type: "string", description: "UUID of the vehicle" },
            service_center_id: { type: "string", description: "UUID of the recommended service center" },
            trip_id: { type: "string", description: "UUID of the trip during which maintenance could occur" }
          },
          required: ["vehicle_id", "service_center_id", "trip_id"]
        }
      end

      def self.execute(params)
        vehicle = Vehicle.find(params["vehicle_id"])
        center = ServiceCenter.find(params["service_center_id"])
        trip = Trip.find(params["trip_id"])

        affected_trips = vehicle.trips.scheduled
          .where("departure_at > ?", trip.departure_at)
          .order(:departure_at)
          .limit(5)

        schedule = Vehicle::MAINTENANCE_SCHEDULE[vehicle.next_maintenance_type&.to_sym]

        {
          vehicle: {
            unit_number: vehicle.unit_number,
            make_model: "#{vehicle.year} #{vehicle.make} #{vehicle.model}",
            current_mileage: vehicle.current_mileage,
            battery_health_percent: vehicle.battery_health_percent
          },
          maintenance: {
            type: vehicle.next_maintenance_type,
            threshold_mileage: vehicle.next_maintenance_due_mileage,
            miles_remaining: vehicle.next_maintenance_due_mileage - vehicle.current_mileage
          },
          service_center: {
            name: center.name,
            city: center.city,
            contact_email: center.contact_email,
            ev_certified: center.ev_certified,
            capabilities: center.capabilities
          },
          trip_context: {
            trip_number: trip.trip_number,
            route: "#{trip.origin} -> #{trip.destination}",
            departure: trip.departure_at.iso8601,
            return: trip.return_at.iso8601
          },
          affected_trips: affected_trips.map { |t|
            { trip_number: t.trip_number, departure: t.departure_at.iso8601, destination: t.destination }
          },
          assumptions: [
            "Service center availability not confirmed — recommend calling ahead",
            "Duration estimate based on standard #{vehicle.next_maintenance_type} (~#{schedule ? schedule[:duration_hours] : 'unknown'} hours)",
            "No technician load or bay capacity data available",
            "Cost estimate: #{schedule ? "$#{schedule[:cost_range].begin}-$#{schedule[:cost_range].end}" : 'varies'}"
          ]
        }
      end
    end
  end
end
