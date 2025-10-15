Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Weather forecast routes
  get 'weather', to: 'weather#index'
  get 'weather/forecast', to: 'weather#forecast'
  get 'weather/health', to: 'weather#health'

  # Root path - redirect to weather forecast page
  root 'weather#index'
end
