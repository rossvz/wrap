Rails.application.routes.draw do
  root "dashboard#index"
  get "dashboard" => "dashboard#index"
  delete "dashboard/clear_day" => "dashboard#clear_day", as: :clear_day

  # User settings
  resource :settings, only: [ :show, :update ]

  # Authentication
  resource :session, only: [ :new, :create, :destroy ] do
    resource :magic_link, only: [ :show, :create ], module: :sessions
  end

  # Standalone route for creating habit logs from the timeline
  resources :habit_logs, only: [ :create ]

  resources :habits do
    resources :habit_logs, path: "logs", only: %i[index create edit update destroy]
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Push notification subscriptions
  resources :push_subscriptions, only: [ :create, :destroy ]

  # Render dynamic PWA files from app/views/pwa/*
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Legacy generator route (keep links clean)
  # get "dashboard/index"
end
