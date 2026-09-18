# frozen_string_literal: true

class AddStatusToAgentConversations < ActiveRecord::Migration[6.1]
  def change
    add_column :agent_conversations, :status, :string, null: false, default: "idle"
    add_column :agent_conversations, :running_started_at, :datetime
    add_index :agent_conversations, :status
  end
end
