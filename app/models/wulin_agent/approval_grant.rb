# frozen_string_literal: true

module WulinAgent
  class ApprovalGrant < ApplicationRecord
    self.table_name = "agent_approval_grants"
    self.filter_attributes += [:params, :token_digest]

    validates :user_id, :token_digest, :tool, :expires_at, presence: true

    # Host subclasses can add tenant scoping or reject inactive users here.
    def self.for_user(user_id)
      where(user_id: user_id)
    end

    def self.available(token, user_id:)
      return none if token.blank?

      for_user(user_id).where(token_digest: Digest::SHA256.hexdigest(token.to_s), consumed_at: nil)
        .where("expires_at > ?", Time.current)
    end

    def grant
      {tool: tool, params: params, user_id: user_id, tool_call_id: tool_call_id, expires_at: expires_at}
    end
  end
end
