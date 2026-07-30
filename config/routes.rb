Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  get "sitemap.xml", to: "sitemaps#show", defaults: { format: :xml }
  get "pricing", to: "landing#pricing"
  post "billing/checkout", to: "billing#checkout"
  post "billing/portal", to: "billing#portal"
  post "webhooks/stripe", to: "stripe_webhooks#create"
  get "seller-demo", to: "demos#seller"
  get "buyer-demo", to: "demos#buyer"

  get "q/:token", to: "buyer_rooms#show", as: :buyer_room
  scope "q/:token", as: :buyer_room do
    get "quote.pdf", to: "buyer_rooms#pdf", as: :pdf
    post "reply", to: "buyer_rooms#reply", as: :reply
    post "questions", to: "buyer_rooms#question", as: :questions
    post "request-changes", to: "buyer_rooms#request_changes", as: :request_changes
    post "accept", to: "buyer_rooms#accept", as: :accept
  end

  devise_for :users, skip: [ :passwords ], controllers: { registrations: "users/registrations", sessions: "users/sessions" }

  # Email verification
  resources :email_verifications, only: [] do
    collection do
      post :resend
      post :verify
    end
  end
  get "pending-email-verification", to: "email_verifications#pending", as: :pending_email_verification
  get "suspended", to: "suspended_access#show", as: :suspended

  # Email change
  post "email-change/request", to: "email_changes#request_change", as: :request_email_change
  get "email-change/confirm/:token", to: "email_changes#confirm", as: :email_change

  authenticated :user do
    root "quotes#index", as: :authenticated_root
  end

  unauthenticated do
    root "landing#index"
  end
  get ":locale", to: "landing#index", as: :localized_root, constraints: { locale: /en|zh-CN/ }

  scope "(:locale)", locale: /en|zh-CN/ do
    get "contact", to: "landing#contact"
    get "privacy", to: "landing#privacy"
    get "terms", to: "landing#terms"
    resources :contact_requests, only: [ :create ]
  end

  resources :inbox, only: :index
  resources :deals, only: %i[index show] do
    member do
      patch "questions/:question_id/reply", action: :reply_question, as: :reply_question
      get :deliver, to: "deal_deliveries#new"
      post :deliver, to: "deal_deliveries#create"
      get "deliveries/:delivery_id/download", to: "deal_deliveries#download", as: :download_delivery
      post "deliveries/:delivery_id/retry", to: "deal_deliveries#retry", as: :retry_delivery
      patch "versions/:version_id/link", to: "deal_deliveries#update_link", as: :version_link
      get "responses/new", to: "deal_responses#new", as: :new_response
      post :responses, to: "deal_responses#create"
      patch "responses/:response_id/apply", to: "deal_responses#apply", as: :apply_response
      patch "responses/:response_id/disposition", to: "deal_responses#disposition", as: :response_disposition
      get "acceptance/new", to: "deal_acceptances#new", as: :new_acceptance
      post :acceptance, to: "deal_acceptances#create"
      patch :close
      patch :reopen
    end
  end
  resources :final_documents, only: %i[show create] do
    member do
      patch :mark_sent
      patch :confirm_payment
      get :pdf
      post :email
    end
  end
  get "library", to: "library#index", as: :library
  resources :product_import_batches, path: "library/catalog-imports", only: %i[new create show update] do
    collection { get :active }
    member do
      post :apply
      post :retry_processing
    end
  end
  resources :inquiries, only: %i[new create show update] do
    resources :inquiry_messages, only: :create
    member do
      post :build_quote
      post :analyze_chat
      get :chat_analysis
    end
  end
  resources :quote_revisions, only: %i[show create]
  resources :notifications, only: [] do
    collection do
      patch :mark_all_read
      get :unread_count
    end
    member do
      get :mark_read
      patch :dismiss
    end
  end

  # Product management
  get "products", to: redirect("/library")
  resources :products, except: :index do
    member do
      patch :set_primary_image
      delete :remove_primary_image
      delete :remove_gallery_image
      delete :bulk_remove_gallery_images
    end
  end
  resource :document_design, only: %i[edit update]
  get "quote_templates", to: redirect("/document_design/edit")
  get "quote_templates/new", to: redirect("/document_design/edit")
  get "quote_templates/:id/edit", to: redirect("/document_design/edit")
  resources :quote_presets, except: [ :show ] do
    member do
      post :duplicate
    end
  end
  resource :quote_preset_master, only: [ :update ]
  resources :company_documents, only: [ :create, :destroy ]
  resources :product_presets, only: [ :index ]
  resources :spec_presets, except: [ :show ]
  resources :addon_presets, except: [ :show ]
  resources :team_members, only: [ :index, :show, :update, :destroy ]
  get "settings/company", to: redirect("/company_settings/edit")
  resource :company_settings, only: [ :edit, :update ]
  resources :company_profile_imports, path: "settings/company-imports", only: %i[new create show update] do
    member { patch :apply }
  end
  resources :quote_reason_options, only: [ :create, :destroy ]
  resources :customers, except: :destroy
  resource :imports, only: :show
  resource :chat_integration, only: :show do
    post :pairing_code
    delete "tokens/:id", action: :revoke, as: :revoke_token
  end

  namespace :api do
    namespace :chat_sync do
      post :pair, to: "pairings#create"
      get :context, to: "contexts#show"
      resources :bindings, only: %i[create update destroy] do
        post :messages, to: "messages#create"
        resource :analysis, only: %i[create show]
      end
    end
  end

  # Quote is the commercial aggregate. Customer-facing output is generated
  # only from an immutable Published Version.
  resources :quotes, only: %i[index new create show edit update] do
    member do
      get :preview
      get :publish
      get :deliver, to: "deal_deliveries#new"
      post :deliver, to: "deal_deliveries#create"
      get "deliveries/:delivery_id/download", to: "deal_deliveries#download", as: :download_delivery
      patch "versions/:version_id/link", to: "deal_deliveries#update_link", as: :version_link
      patch "questions/:question_id/reply", action: :reply_question, as: :reply_question
      patch "change_requests/:change_request_id/apply", action: :apply_change_request, as: :apply_change_request
      get "responses/new", to: "deal_responses#new", as: :new_response
      post :responses, to: "deal_responses#create"
      patch "responses/:response_id/apply", to: "deal_responses#apply", as: :apply_response
      patch "responses/:response_id/disposition", to: "deal_responses#disposition", as: :response_disposition
      get "acceptance/new", to: "deal_acceptances#new", as: :new_acceptance
      post :acceptance, to: "deal_acceptances#create"
    end
    get "versions/:version_id/export/:output", to: "quote_exports#show", as: :version_export
  end
  namespace :admin do
    root "dashboard#index"
    resources :users, only: [ :index, :show ] do
      member do
        patch :update_role
        patch :update_status
        post :grant_vip
        post :send_notification
        post :impersonate
      end
    end
    resources :notifications, only: [ :create ]
    resources :audit_logs, only: [ :index ]
    resource :impersonation, only: [ :destroy ], controller: "impersonations"
  end
end
