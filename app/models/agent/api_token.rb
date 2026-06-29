# frozen_string_literal: true

module Agent
  class ApiToken < ApplicationRecord
    self.table_name = "agent_api_tokens"

    belongs_to :user
    has_secure_token :token

    scope :active, -> {
      where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current)
    }

    def revoke!
      update!(revoked_at: Time.current)
    end

    def active?
      revoked_at.nil? && (expires_at.nil? || expires_at.future?)
    end
  end
end
