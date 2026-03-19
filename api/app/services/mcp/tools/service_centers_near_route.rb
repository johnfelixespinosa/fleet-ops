module Mcp
  module Tools
    class ServiceCentersNearRoute
      def self.tool_name = "service_centers_near_route"

      def self.description
        "Find partner service centers within a given radius of a trip's route. " \
        "Can search along the full route, outbound leg, or return leg."
      end

      def self.input_schema
        {
          type: "object",
          properties: {
            trip_id: { type: "string", description: "UUID of the trip" },
            radius_miles: { type: "integer", description: "Search radius in miles (default: 25)", default: 25 },
            leg: { type: "string", enum: ["outbound", "return", "full"], description: "Which portion of route to search (default: return)", default: "return" }
          },
          required: ["trip_id"]
        }
      end

      def self.execute(params)
        trip_id = params["trip_id"]
        trip = Trip.find_by(trip_number: trip_id) || Trip.find(trip_id)
        radius = (params["radius_miles"] || 25).to_i
        leg = params["leg"] || "return"
        waypoints = trip.route_waypoints || []

        selected = case leg
        when "outbound" then waypoints.first(waypoints.size / 2)
        when "return" then waypoints.last(waypoints.size / 2)
        else waypoints
        end

        return [] if selected.empty?

        centers = ServiceCenter.partners.ev_certified
        results = centers.filter_map do |sc|
          min_distance = selected.map do |wp|
            haversine_miles(wp["lat"], wp["lng"], sc.latitude.to_f, sc.longitude.to_f)
          end.min

          if min_distance <= radius
            {
              service_center_id: sc.id,
              name: sc.name,
              city: sc.city,
              contact_email: sc.contact_email,
              distance_from_route_miles: min_distance.round(1),
              capabilities: sc.capabilities,
              ev_certified: sc.ev_certified
            }
          end
        end

        results.sort_by { |r| r[:distance_from_route_miles] }
      end

      def self.summary(results, params)
        trip = Trip.find_by(id: params["trip_id"])
        leg = params["leg"] || "return"
        radius = params["radius_miles"] || 25
        route_desc = trip ? "#{trip.origin} → #{trip.destination}" : "the route"
        if results.empty?
          "No EV-certified partner service centers found within #{radius} miles of the #{leg} leg of #{route_desc}."
        else
          names = results.map { |c| "#{c[:name]} in #{c[:city]} (#{c[:distance_from_route_miles]} mi from route)" }.join("; ")
          "Found #{results.size} service center#{"s" if results.size > 1} near the #{leg} leg of #{route_desc}: #{names}"
        end
      end

      def self.haversine_miles(lat1, lng1, lat2, lng2)
        rad = Math::PI / 180
        dlat = (lat2 - lat1) * rad
        dlng = (lng2 - lng1) * rad
        a = Math.sin(dlat / 2)**2 + Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(dlng / 2)**2
        3959 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
      end
    end
  end
end
