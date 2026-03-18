class VehiclesController < ApplicationController
  def index
    @vehicles = Vehicle.order(:unit_number)
  end

  def show
    @vehicle = Vehicle.find(params[:id])
    @upcoming_trips = @vehicle.trips.scheduled.order(:departure_at)
    @recent_trips = @vehicle.trips.recent.limit(10)
    @maintenance_history = @vehicle.maintenance_records.recent.limit(10)
    @recent_charging = @vehicle.charging_events.recent.limit(10)
  end
end
