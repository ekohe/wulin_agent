# frozen_string_literal: true

module WulinAgent
  module Approvals
    TTL = 10.minutes

    def self.needs_approval?(tool, mode:, approved: false)
      return false if approved
      return false if mode == :auto
      return true if mode == :confirm_all
      return tool.mutating if mode == :confirm_writes
      return true
    end

    def self.issue!(tool:, params:, user_id:, tool_call_id: nil)
      grant_class.for_user(user_id).where("expires_at <= ?", Time.current).limit(100).delete_all
      token = SecureRandom.uuid
      grant_class.create!(token_digest: Digest::SHA256.hexdigest(token),
        tool: tool, params: params || {}, user_id: user_id, tool_call_id: tool_call_id, expires_at: TTL.from_now)
      token
    end

    # Compatibility with callers resetting the old process-local store. Durable
    # grants survive process resets; tests should use database transactions.
    def self.reset!
    end

    def self.consume!(token, user_id:)
      available = grant_class.available(token, user_id: user_id)
      record = available.first
      return unless record

      # Only one process can claim this row, even if several read it first.
      return unless available.where(id: record.id).update_all(consumed_at: Time.current) == 1

      record.grant
    end

    def self.fetch!(token, user_id:)
      grant_class.available(token, user_id: user_id).first&.grant
    end

    def self.rejection_result(tool:, reason:)
      {
        "status" => "rejected",
        "tool" => tool,
        "reason" => reason,
        "instruction" => "The user declined this action. Do not retry this tool or call any other tools. Reply in plain text only: briefly acknowledge what was declined."
      }
    end

    def self.grant_class
      WulinAgent.config.approval_grant_class.constantize
    end
    private_class_method :grant_class
  end
end
