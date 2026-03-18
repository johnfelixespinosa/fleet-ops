# == Schema Information
#
# Table name: trips
#
#  id                  :uuid             not null, primary key
#  cargo_weight_lbs    :integer
#  departure_at        :datetime
#  destination         :string
#  distance_miles      :integer
#  energy_consumed_kwh :decimal(, )
#  origin              :string
#  return_at           :datetime
#  route_waypoints     :jsonb
#  status              :string
#  trip_number         :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  vehicle_id          :uuid             not null
#
# Indexes
#
#  index_trips_on_trip_number            (trip_number) UNIQUE
#  index_trips_on_vehicle_id             (vehicle_id)
#  index_trips_on_vehicle_id_and_status  (vehicle_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (vehicle_id => vehicles.id)
#
class Trip < ApplicationRecord
  belongs_to :vehicle

  enum :status, { scheduled: "scheduled", in_progress: "in_progress", completed: "completed", cancelled: "cancelled" }

  validates :trip_number, presence: true, uniqueness: true
  validates :status, presence: true

  scope :upcoming, ->(days) { scheduled.where(departure_at: Time.current..days.days.from_now) }
  scope :recent, -> { completed.order(return_at: :desc) }
end
