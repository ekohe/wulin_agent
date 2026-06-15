# frozen_string_literal: true

module WulinAgent
  module Approval
    def self.needs_approval?(tool, mode:, approved: false)
      return false if approved
      return false if mode == :auto
      return true if mode == :confirm_all
      return tool.mutating if mode == :confirm_writes
      return true
    end
  end
end