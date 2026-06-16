# config/routes.rb
Rails.application.routes.draw do
  namespace :agent do
    resources :conversations, only: [:create, :show] do
      member do
        post :approve
        post :reject
      end
    end
  end
end