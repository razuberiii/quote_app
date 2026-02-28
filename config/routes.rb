Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :users, skip: [ :passwords ]

  authenticated :user do
    root "customers#index", as: :authenticated_root
  end

  unauthenticated do
    root "landing#index"
  end
  get "demo", to: "landing#demo"
  get "sample-quote", to: "landing#sample_quote"
  resources :contact_requests, only: [ :create ]

  # Public quote sharing
  namespace :public do
    resources :quote_shares, only: [ :show ], param: :token
  end

  # Product management
  resources :products do
    member do
      patch :set_primary_image
      delete :remove_primary_image
      delete :remove_gallery_image
    end
  end
  resources :quote_templates, except: [ :show ] do
    member do
      patch :set_default
    end
  end

  resources :customers do
    member do
      post :mark_follow_up
    end

    resources :quotes, shallow: true do
      member do
        post :duplicate
        post :duplicate_and_reprice
        post :share
        patch :update_template
        get "export/pdf", action: :export_pdf, as: :export_pdf
        get "export/xlsx", action: :export_xlsx, as: :export_xlsx
      end
    end
  end

  get "quote/:id/export_pdf", to: "quotes#export_pdf", as: :legacy_export_pdf_quote
  get "quote/:id/export_excel", to: "quotes#export_xlsx", as: :legacy_export_excel_quote

  namespace :admin do
    resources :users, only: [ :index, :update ]
  end
end
