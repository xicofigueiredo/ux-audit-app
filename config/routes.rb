Rails.application.routes.draw do
  # Health endpoints (available on all domains)
  get "up" => "rails/health#show", as: :rails_health_check
  get "health" => "health#show"

  # Sidekiq web interface (protect in production)
  if Rails.env.development?
    require 'sidekiq/web'
    mount Sidekiq::Web => '/sidekiq'
  end

  # Devise authentication (available on all domains for sign in/sign out)
  devise_for :users, controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations'
  }

  # Web App Routes (app.uxauditapp.com or app.uxauditapp.local)
  constraints(Constraints::SubdomainConstraint.new('app')) do
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

    # Settings
    get 'settings', to: 'settings#index', as: :settings

    # Root of app subdomain goes to projects
    root "projects#index", as: :app_root
  end

  # Marketing Site Routes (uxauditapp.com, www.uxauditapp.com, and localhost in development)
  constraints(Constraints::SubdomainConstraint.new(nil, 'www')) do
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
  # This allows localhost:3001 to work like a full app without needing subdomains
  if Rails.env.development?
    # Only define these if we haven't already (i.e., we're on plain localhost, not constrained routes)
    # App routes (accessible without subdomain on localhost)
    resources :video_audits, only: [:create, :show, :index, :destroy] unless defined?(video_audits_path)
    resources :projects, only: [:index] unless defined?(projects_path)

    # Settings (accessible without subdomain on localhost)
    get 'settings', to: 'settings#index' unless defined?(settings_path)
  end
end
