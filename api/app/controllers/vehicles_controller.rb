class VehiclesController < ApplicationController
  include Paginatable

  def index
    @vehicles = Vehicle.order(:unit_number)
  end

  def show
    @vehicle = Vehicle.find(params[:id])
    @upcoming_trips_pagination = paginate(@vehicle.trips.scheduled.order(:departure_at), param_name: :upcoming_page)
    @upcoming_trips = @upcoming_trips_pagination[:records]
    @recent_trips_pagination = paginate(@vehicle.trips.recent, param_name: :recent_page)
    @recent_trips = @recent_trips_pagination[:records]
    @maintenance_pagination = paginate(@vehicle.maintenance_records.recent, param_name: :maint_page)
    @maintenance_history = @maintenance_pagination[:records]
    @charging_pagination = paginate(@vehicle.charging_events.recent, param_name: :charging_page)
    @recent_charging = @charging_pagination[:records]
  end
end
