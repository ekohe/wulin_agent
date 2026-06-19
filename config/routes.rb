# config/routes.rb
Rails.application.routes.draw do
  namespace :agent do
    resources :conversations, only: [:index, :create, :show, :update] do
      member do
        post :approve
        post :reject
      end
    end
  end
end