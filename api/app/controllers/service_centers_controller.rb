class ServiceCentersController < ApplicationController
  def index
    @service_centers = ServiceCenter.order(:name)
  end
end
