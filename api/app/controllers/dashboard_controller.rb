class DashboardController < ApplicationController
  include Paginatable

  def index
    @vehicle_count = Vehicle.count
    @active_count = Vehicle.active.count
    @needing_attention = Vehicle.needing_attention.order(:unit_number)
    @low_battery = Vehicle.low_battery.active
    @avg_battery_health = Vehicle.active.average(:battery_health_percent)&.round || 0
    @upcoming_trips_pagination = paginate(
      Trip.scheduled.where(departure_at: ..7.days.from_now).order(:departure_at),
      param_name: :page, per_page: 10
    )
    @upcoming_trips = @upcoming_trips_pagination[:records]
  end
end
