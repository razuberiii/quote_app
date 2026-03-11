Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  get "sitemap.xml", to: "sitemaps#show", defaults: { format: :xml }

  devise_for :users, skip: [ :passwords ], controllers: { registrations: "users/registrations", sessions: "users/sessions" }

  # Email verification
  resources :email_verifications, only: :show, param: :token do
    collection do
      post :resend
    end
  end
  get "pending-email-verification", to: "email_verifications#pending", as: :pending_email_verification

  # Email change
  post "email-change/request", to: "email_changes#request_change", as: :request_email_change
  get "email-change/confirm/:token", to: "email_changes#confirm", as: :email_change

  authenticated :user do
    root "dashboard#index", as: :authenticated_root
  end

  unauthenticated do
    root "landing#index"
  end
  get "demo", to: "landing#demo"
  get "dashboard", to: "dashboard#index"
  get "sample-quote", to: "landing#sample_quote"
  get "foreign-trade-quotation-software", to: "seo#foreign_trade_quotation_software"
  get "quotation-crm-for-export-teams", to: "seo#quotation_crm_for_export_teams"
  resources :contact_requests, only: [ :create ]

  resources :notifications, only: [] do
    collection do
      patch :mark_all_read
      get :unread_count
    end
    member do
      get :mark_read
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

  resources :customers do
    member do
      post :mark_follow_up
      post :schedule_follow_up
      post :log_follow_up
      post :send_follow_up_email
      post :send_follow_up_whatsapp
    end

    resources :quotes, shallow: true do
      member do
        post :duplicate
        post :duplicate_and_reprice
        post :archive
        post :reopen
        post :share
        post :send_reminder
        patch :update_outcome_reason
        patch :update_template
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
    resources :users, only: [ :index, :update ]
  end
end
