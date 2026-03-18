# == Schema Information
#
# Table name: charging_events
#
#  id               :uuid             not null, primary key
#  charge_rate_kw   :decimal(, )
#  charged_at       :datetime
#  cost             :decimal(, )
#  duration_minutes :integer
#  energy_added_kwh :decimal(, )
#  latitude         :decimal(, )
#  location_type    :string
#  longitude        :decimal(, )
#  station_name     :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  trip_id          :uuid
#  vehicle_id       :uuid             not null
#
# Indexes
#
#  index_charging_events_on_trip_id     (trip_id)
#  index_charging_events_on_vehicle_id  (vehicle_id)
#
# Foreign Keys
#
#  fk_rails_...  (trip_id => trips.id)
#  fk_rails_...  (vehicle_id => vehicles.id)
#
class ChargingEvent < ApplicationRecord
  belongs_to :vehicle
  belongs_to :trip, optional: true

  scope :depot, -> { where(location_type: "depot") }
  scope :en_route, -> { where(location_type: "en_route") }
  scope :recent, -> { order(charged_at: :desc) }
end
