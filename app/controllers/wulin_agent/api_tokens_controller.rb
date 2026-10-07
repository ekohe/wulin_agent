# frozen_string_literal: true

module WulinAgent
  class ApiTokensController < ApplicationController
    EXPIRY_DAYS = %w[7 30 90 365 never].freeze

    before_action :require_token_user!
    before_action :prevent_caching

    def index
      render json: user_tokens.active.order(created_at: :desc).map { |token| token_payload(token) }
    end

    def create
      attributes = params.permit(:name, :expires_in_days)
      name = attributes[:name].to_s.strip
      expiry = attributes[:expires_in_days].presence || "30"
      unless name.present? && name.length <= 100
        return render json: {error: "Enter a token name of 1–100 characters."}, status: :unprocessable_entity
      end
      unless EXPIRY_DAYS.include?(expiry.to_s)
        return render json: {error: "Choose a valid expiration."}, status: :unprocessable_entity
      end

      token = user_tokens.create!(name: name, expires_at: (expiry.to_i.days.from_now unless expiry == "never"))
      render json: token_payload(token).merge(token: token.token), status: :created
    end

    def destroy
      user_tokens.find(params[:id]).revoke!
      head :no_content
    end

    private

    def require_token_user!
      return head :unauthorized unless current_user
      head :unauthorized if current_user.respond_to?(:active?) && !current_user.active?
    end

    def prevent_caching
      response.set_header("Cache-Control", "no-store")
    end

    def user_tokens
      scope = WulinAgent::ApiToken.where(user_id: current_user.id)
      if WulinAgent::ApiToken.column_names.include?("workspace_id") && current_user.respond_to?(:workspace_id)
        scope = scope.where(workspace_id: current_user.workspace_id)
      end
      scope
    end

    def token_payload(token)
      {
        id: token.id,
        name: token.name,
        created_at: token.created_at.iso8601,
        expires_at: token.expires_at&.iso8601,
        last_used_at: token.last_used_at&.iso8601
      }
    end
  end
end
