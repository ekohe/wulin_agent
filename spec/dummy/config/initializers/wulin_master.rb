# frozen_string_literal: true

WulinMaster.configure do |config|
  config.app_title = "WulinAgent Dummy"
end

Rails.application.config.to_prepare do
  WulinMaster::GridStatesManagesController.class_eval do
    def current_user
      @current_user ||= User.find_by(id: session[:user_id]) ||
        User.find_by(admin: true) ||
        User.order(:id).first
    end
  end
end
