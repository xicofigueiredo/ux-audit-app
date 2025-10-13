require_relative '../lib/constraints/subdomain_constraint'

Rails.application.routes.draw do
  # Health endpoints (available on all domains)
  get "up" => "rails/health#show", as: :rails_health_check
  get "health" => "health#show"

  # Sidekiq web interface (protect in production)
  if Rails.env.development?
    require 'sidekiq/web'
    mount Sidekiq::Web => '/sidekiq'
  end

  # Web App Routes (app.uxauditapp.com or app.uxauditapp.local)
  constraints(SubdomainConstraint.new('app')) do
    # Authenticated application routes
    resources :video_audits, only: [:create, :show, :index, :destroy]
    resources :projects, only: [:index]

    # Knowledge base management (admin features)
    resources :ux_knowledge_documents, only: [:index, :show] do
      collection do
        get :search
        get :reindex
        post :reindex
      end
    end

    # Root of app subdomain goes to projects
    root "projects#index", as: :app_root
  end

  # Marketing Site Routes (uxauditapp.com, www.uxauditapp.com, and localhost in development)
  constraints(SubdomainConstraint.new(nil, 'www')) do
    # Devise authentication (sign in/sign up on marketing domain)
    devise_for :users, controllers: {
      sessions: 'users/sessions',
      registrations: 'users/registrations'
    }

    # Public marketing pages
    root "pages#home", as: :marketing_root
    get "demo" => "pages#demo"
    post "feedback" => "feedback#create"

    # Public knowledge base (read-only)
    resources :ux_knowledge_documents, only: [:index, :show] do
      collection do
        get :search
      end
    end

    # Redirect authenticated users trying to access app features to app subdomain
    # Only redirect in production, not on localhost in development
    unless Rails.env.development?
      get "video_audits" => redirect { |params, request| "#{request.protocol}app.#{request.domain}#{request.port == 80 || request.port == 443 ? '' : ":#{request.port}"}/video_audits" }
      get "projects" => redirect { |params, request| "#{request.protocol}app.#{request.domain}#{request.port == 80 || request.port == 443 ? '' : ":#{request.port}"}/projects" }
    end
  end

  # Fallback routes for development on localhost (no subdomain constraints)
  # These will only match if no constrained routes matched above
  unless Rails.env.production?
    # Marketing pages (accessible without subdomain on localhost)
    root "pages#home"
    get "demo" => "pages#demo", as: :fallback_demo unless defined?(demo_path)
    post "feedback" => "feedback#create", as: :fallback_feedback unless defined?(feedback_path)

    # Public knowledge base
    resources :ux_knowledge_documents, only: [:index, :show], as: :fallback_ux_knowledge_documents do
      collection do
        get :search
      end
    end

    # App routes (accessible without subdomain on localhost)
    resources :video_audits, only: [:create, :show, :index, :destroy], as: :fallback_video_audits
    resources :projects, only: [:index], as: :fallback_projects
  end
end
