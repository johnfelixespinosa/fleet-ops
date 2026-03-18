# == Schema Information
#
# Table name: vehicles
#
#  id                           :uuid             not null, primary key
#  annual_inspection_due        :date
#  battery_capacity_kwh         :decimal(, )
#  battery_health_percent       :decimal(, )
#  current_mileage              :integer
#  daily_inspection_current     :boolean
#  last_maintenance_date        :date
#  make                         :string
#  model                        :string
#  next_maintenance_due_mileage :integer
#  next_maintenance_type        :string
#  range_miles                  :integer
#  status                       :string           not null
#  unit_number                  :string           not null
#  year                         :integer
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#
# Indexes
#
#  index_vehicles_on_status       (status)
#  index_vehicles_on_unit_number  (unit_number) UNIQUE
#
class Vehicle < ApplicationRecord
  has_many :trips, dependent: :destroy
  has_many :maintenance_records, dependent: :destroy
  has_many :charging_events, dependent: :destroy

  MAINTENANCE_SCHEDULE = {
    safety_check:          { interval: 15_000, cost_range: 150..300,    duration_hours: 1.5..2.5 },
    standard_service:      { interval: 30_000, cost_range: 400..800,    duration_hours: 3.0..5.0 },
    comprehensive_service: { interval: 60_000, cost_range: 1_200..2_500, duration_hours: 6.0..10.0 },
    major_overhaul:        { interval: 100_000, cost_range: 3_000..8_000, duration_hours: 16.0..24.0 }
  }.freeze

  def next_maintenance_schedule
    MAINTENANCE_SCHEDULE[next_maintenance_type&.to_sym]
  end

  def miles_to_maintenance
    next_maintenance_due_mileage - current_mileage
  end

  def maintenance_urgent?(horizon_miles = 1000)
    miles_to_maintenance <= horizon_miles
  end

  enum :status, { active: "active", in_shop: "in_shop", out_of_service: "out_of_service", retired: "retired" }
  enum :next_maintenance_type, {
    safety_check: "safety_check",
    standard_service: "standard_service",
    comprehensive_service: "comprehensive_service",
    major_overhaul: "major_overhaul"
  }, prefix: :maintenance

  validates :unit_number, presence: true, uniqueness: true
  validates :status, presence: true

  # Dashboard scopes (Mastodon/reservations pattern)
  scope :needing_attention, -> { active.where("next_maintenance_due_mileage - current_mileage < 5000") }
  scope :due_for_maintenance, ->(within_miles) { where("current_mileage + ? >= next_maintenance_due_mileage", within_miles) }
  scope :low_battery, -> { where("battery_health_percent < ?", 95) }

  # Status subsets (rescue-rails Dog pattern)
  OPERATIONAL_STATUSES = %w[active].freeze
  ATTENTION_STATUSES = %w[in_shop out_of_service].freeze
end
