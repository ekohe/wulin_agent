# frozen_string_literal: true

class CreateAgentMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_messages do |t|
      t.references :conversation, null: false, foreign_key: {to_table: :agent_conversations}
      t.string :role, null: false
      t.text :content
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :agent_messages, [:conversation_id, :created_at]
  end
end
