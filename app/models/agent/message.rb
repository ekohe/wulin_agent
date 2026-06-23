# frozen_string_literal: true

module Agent
  class Message < ApplicationRecord
    self.table_name = "agent_messages"

    ROLES = %w[user assistant].freeze

    belongs_to :conversation,
      class_name: "Agent::Conversation",
      inverse_of: :messages

    validates :role, inclusion: {in: ROLES}
    validates :content, presence: true, unless: :tool_only_assistant_message?

    def tool_only_assistant_message?
      role == "assistant" &&
        metadata.is_a?(Hash) &&
        metadata["tool_calls"].present?
    end

    scope :chronological, -> { order(:created_at) }
  end
end
