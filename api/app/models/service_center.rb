# == Schema Information
#
# Table name: service_centers
#
#  id            :uuid             not null, primary key
#  address       :string
#  capabilities  :jsonb
#  city          :string
#  contact_email :string
#  ev_certified  :boolean
#  is_partner    :boolean
#  latitude      :decimal(, )
#  longitude     :decimal(, )
#  name          :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
class ServiceCenter < ApplicationRecord
  has_many :maintenance_records

  scope :partners, -> { where(is_partner: true) }
  scope :ev_certified, -> { where(ev_certified: true) }
end
