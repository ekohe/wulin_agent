# frozen_string_literal: true

module Agent
  class Conversation < ApplicationRecord
    self.table_name = "agent_conversations"

    APPROVAL_MODES = %w[auto confirm_writes confirm_all].freeze

    belongs_to :user
    has_many :messages,
      class_name: "Agent::Message",
      foreign_key: :conversation_id,
      dependent: :destroy,
      inverse_of: :conversation

    validates :approval_mode, inclusion: {in: APPROVAL_MODES}

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
