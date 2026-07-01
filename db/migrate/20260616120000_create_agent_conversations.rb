# frozen_string_literal: true

class CreateAgentConversations < ActiveRecord::Migration[6.1]
  def change
    create_table :agent_conversations do |t|
      t.references :user, null: false, foreign_key: false, index: true
      t.string :title
      t.string :approval_mode, null: false, default: "confirm_writes"

      t.timestamps
    end

    add_index :agent_conversations, [:user_id, :updated_at]
  end
end
