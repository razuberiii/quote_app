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
    root "inbox#index", as: :authenticated_root
  end

  unauthenticated do
    root "landing#index"
  end
  get ":locale", to: "landing#index", as: :localized_root, constraints: { locale: /en|zh-CN|es-419/ }

  scope "(:locale)", locale: /en|zh-CN|es-419/ do
    get "demo", to: "landing#demo"
    get "contact", to: "landing#contact"
    get "privacy", to: "landing#privacy"
    get "terms", to: "landing#terms"
    get "sample-quote", to: "landing#sample_quote"
    get "foreign-trade-quotation-software", to: "seo#foreign_trade_quotation_software"
    get "quote-revision-control", to: "seo#quote_revision_control"
    get "buyer-facing-quotation-link", to: "seo#buyer_facing_quotation_link"
    get "quotation-software-vs-excel", to: "seo#quotation_software_vs_excel"
    get "quotation-software-vs-erp", to: "seo#quotation_software_vs_erp"
    get "quick-export-quotation", to: "seo#quick_export_quotation"
    get "resources", to: "seo#resources"
    resources :contact_requests, only: [ :create ]
  end

  get "dashboard", to: "dashboard#index"
  get "quotes", to: redirect("/deals"), as: :all_quotes
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
      get :pdf
      post :email
    end
  end
  get "library", to: "library#index", as: :library
  resources :inquiries, only: %i[index new create show update] do
    member { post :build_quote }
  end
  resources :quote_revisions, only: %i[show create]
  resources :proforma_invoices, only: %i[show create] do
    member do
      patch :deposit_received
      patch :mark_sent
      get :pdf
    end
  end
  patch "onboarding/dismiss", to: "onboarding#dismiss", as: :dismiss_onboarding

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

  # Public quote sharing
  namespace :public do
    resources :quote_shares, only: [ :show ], param: :token do
      member do
        post :accept
        post :request_revision
      end
    end
    resources :quote_view_events, only: :create
  end

  # Product management
  resources :products do
    member do
      patch :set_primary_image
      delete :remove_primary_image
      delete :remove_gallery_image
      delete :bulk_remove_gallery_images
    end
  end
  resources :quote_templates, except: [ :show ] do
    member do
      patch :set_default
    end
  end
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
  resources :team_invitations, only: [ :index, :create, :destroy ], param: :token do
    member do
      post :accept
    end
  end
  resource :company_settings, only: [ :edit, :update ]
  resources :quote_reason_options, only: [ :create, :destroy ]

  get "command_palette/search", to: "command_palette#search", as: :command_palette_search

  resources :customers do
    collection do
      get :shortcut_candidates
    end

    member do
      patch :pause
      patch :resume
      post :mark_follow_up
      post :schedule_follow_up
      post :log_follow_up
      post :send_follow_up_email
      post :send_follow_up_whatsapp
      patch :reorder_tags
    end

    resources :quotes, shallow: true do
      member do
        post :duplicate
        post :archive
        post :mark_sent
        post :mark_negotiating
        post :revert_to_sent
        post :undo_status_change
        post :reopen
        post :share
        post :send_reminder
        patch :mark_outcome
        patch :update_outcome_reason
        patch :update_template
        post :create_pi
        get :public_preview
        get "export/pdf", action: :export_pdf, as: :export_pdf
        get "export/xlsx", action: :export_xlsx, as: :export_xlsx
      end
    end
  end

  get "quote/:id/export_pdf", to: "quotes#export_pdf", as: :legacy_export_pdf_quote
  get "quote/:id/export_excel", to: "quotes#export_xlsx", as: :legacy_export_excel_quote
  resources :action_items, only: [] do
    member do
      patch :resolve
    end
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
