# frozen_string_literal: true

module WulinAgent
  class Conversation < ApplicationRecord
    self.table_name = "agent_conversations"

    APPROVAL_MODES = %w[auto confirm_writes confirm_all].freeze
    STATUSES = %w[idle running].freeze
    RUNNING_TIMEOUT = 10.minutes

    belongs_to :user, optional: true
    has_many :messages,
      class_name: "WulinAgent::Message",
      foreign_key: :conversation_id,
      dependent: :destroy,
      inverse_of: :conversation

    validates :approval_mode, inclusion: {in: APPROVAL_MODES}
    validates :status, inclusion: {in: STATUSES}

    def running?
      return false unless status == "running"

      if running_started_at && running_started_at < RUNNING_TIMEOUT.ago
        update!(status: "idle", running_started_at: nil)
        return false
      end

      true
    end

    def mark_running!
      update!(status: "running", running_started_at: Time.current)
    end

    def mark_idle!
      update!(status: "idle", running_started_at: nil)
    end

    def approval_mode_sym
      approval_mode.to_sym
    end

    def history_for_runner(limit: WulinAgent::Runner::MAX_CONTEXT_MESSAGES, exclude_last: false)
      scope = messages.chronological.to_a
      scope = scope[0...-1] if exclude_last && scope.any?
      scope.last(limit).map do |message|
        entry = {role: message.role.to_sym, content: message.content}
        entry[:metadata] = message.metadata if message.metadata.present?
        entry
      end
    end
  end
end
