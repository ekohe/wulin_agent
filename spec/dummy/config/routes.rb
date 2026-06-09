Rails.application.routes.draw do
  root to: "homepage#index"

  mount WulinAgent::Engine => "/wulin_agent"
end
