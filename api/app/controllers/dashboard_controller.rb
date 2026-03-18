class DashboardController < ApplicationController
  def index
    @vehicle_count = Vehicle.count
    @active_count = Vehicle.active.count
    @needing_attention = Vehicle.needing_attention.order(:unit_number)
    @low_battery = Vehicle.low_battery.active
    @upcoming_trips = Trip.scheduled.where(departure_at: ..7.days.from_now).order(:departure_at).limit(10)
    @avg_battery_health = Vehicle.active.average(:battery_health_percent)&.round || 0
  end
end
