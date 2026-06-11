Rails.application.routes.draw do
  resources :people do
    post :greet, on: :collection
    post :tag, on: :collection
  end
  root to: "homepage#index"

  mount WulinAgent::Engine => "/wulin_agent"
end
