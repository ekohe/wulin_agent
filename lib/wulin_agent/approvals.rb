# frozen_string_literal: true

module WulinAgent
  module Approvals
    def self.needs_approval?(tool, mode:, approved: false)
      return false if approved
      return false if mode == :auto
      return true if mode == :confirm_all
      return tool.mutating if mode == :confirm_writes
      return true
    end

    def self.issue!(tool:, params:, user_id:, tool_call_id: nil)
      token = SecureRandom.uuid
      store[token] = {tool:, params:, user_id:, tool_call_id:, expires_at: 5.minutes.from_now}
      token
    end

    def self.reset!
      @store = {}
    end

    def self.consume!(token, user_id:)
      grant = store.delete(token)
      return nil unless grant
      return nil if grant[:user_id] != user_id
      return nil if grant[:expires_at] < Time.current
      grant
    end

    def self.store
      @store ||= {}
    end
  end
end