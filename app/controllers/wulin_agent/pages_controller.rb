# frozen_string_literal: true

module WulinAgent
  class PagesController < ApplicationController
    # The page renders the host's /menu partial, which reads controller.menu.
    # wulin_master's own controllers get it this way; the host's
    # ApplicationController has define_menu but not the menu itself.
    include WulinMaster::Menuable

    define_menu if respond_to?(:define_menu)

    def show
      return head :unauthorized unless current_user

      render layout: request.xhr? ? false : "application"
    end
  end
end
