Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations'
  }
  # UX Knowledge Base management
  resources :ux_knowledge_documents, only: [:index, :show] do
    collection do
      get :search
      get :reindex
      post :reindex
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Health monitoring endpoint for Kamal/Traefik
  get "health" => "health#show"

  # Defines the root path route ("/")
  resources :video_audits, only: [:create, :show, :index, :destroy]
  resources :projects, only: [:index]
  get "demo" => "pages#demo"
  root "pages#home"

  # Sidekiq web interface (protect in production)
  if Rails.env.development?
    require 'sidekiq/web'
    mount Sidekiq::Web => '/sidekiq'
  end
end
