# frozen_string_literal: true

module WulinAgent
  module Approvals
    TTL = 10.minutes
    # An expired grant is kept this long, so an answer that arrives late is told
    # "expired" rather than "unknown".
    RETENTION = 1.day

    Issued = Data.define(:token, :expires_at)

    # outcome is :granted, or :expired when the answer came after expires_at.
    # Either way the grant is spent: an expired request never runs.
    Claim = Data.define(:outcome, :grant) do
      def expired?
        outcome == :expired
      end
    end

    class UnknownToken < ArgumentError
      def initialize(message = "This approval request was already answered or is no longer available.")
        super
      end
    end

    def self.needs_approval?(tool, mode:, approved: false)
      return false if approved
      return false if mode == :auto
      return true if mode == :confirm_all
      return tool.mutating if mode == :confirm_writes
      true
    end

    def self.issue!(tool:, params:, user_id:, tool_call_id: nil)
      grant_class.for_user(user_id).where("expires_at <= ?", RETENTION.ago).limit(100).delete_all
      token = SecureRandom.uuid
      record = grant_class.create!(token_digest: Digest::SHA256.hexdigest(token),
        tool: tool, params: params || {}, user_id: user_id, tool_call_id: tool_call_id, expires_at: TTL.from_now)
      Issued.new(token: token, expires_at: record.expires_at)
    end

    # Compatibility with callers resetting the old process-local store. Durable
    # grants survive process resets; tests should use database transactions.
    def self.reset!
    end

    # Spends the grant behind token, once, for its user. Raises UnknownToken when
    # there is none: another user's token, an answered one, or one long gone.
    def self.claim!(token, user_id:)
      record = grant_class.unconsumed(token, user_id: user_id).first
      raise UnknownToken unless record

      # Only one process can claim this row, even if several read it first.
      raise UnknownToken unless grant_class.where(id: record.id, consumed_at: nil).update_all(consumed_at: Time.current) == 1

      Claim.new(outcome: (record.expires_at > Time.current) ? :granted : :expired, grant: record.grant)
    end

    def self.fetch!(token, user_id:)
      grant_class.available(token, user_id: user_id).first&.grant
    end

    # When token stops accepting an answer, or nil when it already has: it was
    # answered, it expired, or it never existed.
    def self.pending_expiry(token, user_id:)
      grant_class.available(token, user_id: user_id).pick(:expires_at)
    end

    def self.rejection_result(tool:, reason:)
      {
        "status" => "rejected",
        "tool" => tool,
        "reason" => reason,
        "instruction" => "The user declined this action. Do not retry this tool or call any other tools. Reply in plain text only: briefly acknowledge what was declined."
      }
    end

    def self.expiry_result(tool:)
      {
        "status" => "expired",
        "tool" => tool,
        "reason" => "The approval request expired after #{TTL.in_minutes.to_i} minutes without an answer.",
        "instruction" => "The request expired before the user answered, so the tool did not run. Do not retry this tool or call any other tools. Reply in plain text only: say the request expired and offer to prepare it again."
      }
    end

    def self.grant_class
      WulinAgent.config.approval_grant_class.constantize
    end
    private_class_method :grant_class
  end
end
