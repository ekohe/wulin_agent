# config/routes.rb
Rails.application.routes.draw do
  namespace :wulin_agent, module: "wulin_agent" do
    get "/", to: "pages#show", as: :page
    match "mcp", to: "mcp#handle", via: %i[post delete]
    resources :conversations, only: [:index, :create, :show, :update, :destroy] do
      collection do
        get :agent_config
        post :upload_archive
      end
      member do
        post :approve
        post :reject
        post :feedback
      end
    end
  end
end
