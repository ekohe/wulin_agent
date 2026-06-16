# frozen_string_literal: true

class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) ||
      User.find_by(admin: true) ||
      User.order(:id).first
  end

  def self.define_menu
    menu do |_c|
      submenu "Default" do
        item PersonScreen, icon: :people, label: "People"
      end
    end
  end
end
