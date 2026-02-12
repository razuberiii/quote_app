Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :users

  # Public quote sharing
  namespace :public do
    resources :quotes, only: [ :show ]
    resources :quote_shares, only: [ :show ], param: :token
  end

  # Product management
  resources :products
  resource :quote_template, only: [ :edit, :update ]

  resources :customers do
    member do
      post :mark_follow_up
    end
    resources :quotes, shallow: true do
      member do
        post :duplicate
        post :share
        get "export/pdf", action: :export_pdf, as: :export_pdf
        get "export/xlsx", action: :export_xlsx, as: :export_xlsx
      end
    end
  end

  namespace :admin do
    resources :users, only: [ :index, :update ]
  end

  root "customers#index"
end
