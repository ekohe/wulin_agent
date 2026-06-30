# config/routes.rb
Rails.application.routes.draw do
  namespace :wulin_agent, module: "wulin_agent" do
    match "mcp", to: "mcp#handle", via: %i[post delete]
    resources :conversations, only: [:index, :create, :show, :update] do
      collection do
        get :agent_config
      end
      member do
        post :approve
        post :reject
        post :feedback
      end
    end
  end
end
