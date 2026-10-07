# frozen_string_literal: true

module WulinAgent
  class PagesController < ApplicationController
    def show
      return head :unauthorized unless current_user

      render layout: request.xhr? ? false : "application"
    end
  end
end
