Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#index"
  resources :vehicles, only: [:index, :show]
  resources :service_centers, only: [:index]
  resources :copilot_sessions, only: [:index, :show, :create], path: "sessions"
end
