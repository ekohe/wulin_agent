Rails.application.routes.draw do
  resources :people
  root to: "homepage#index"

  mount WulinAgent::Engine => "/wulin_agent"
end
