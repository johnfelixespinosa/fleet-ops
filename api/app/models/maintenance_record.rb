# == Schema Information
#
# Table name: maintenance_records
#
#  id                 :uuid             not null, primary key
#  completed_at       :datetime
#  cost               :decimal(, )
#  description        :text
#  duration_hours     :decimal(, )
#  maintenance_type   :string
#  mileage_at_service :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  service_center_id  :uuid             not null
#  vehicle_id         :uuid             not null
#
# Indexes
#
#  index_maintenance_records_on_service_center_id  (service_center_id)
#  index_maintenance_records_on_vehicle_id         (vehicle_id)
#
# Foreign Keys
#
#  fk_rails_...  (service_center_id => service_centers.id)
#  fk_rails_...  (vehicle_id => vehicles.id)
#
class MaintenanceRecord < ApplicationRecord
  belongs_to :vehicle
  belongs_to :service_center

  scope :recent, -> { order(completed_at: :desc) }
end
