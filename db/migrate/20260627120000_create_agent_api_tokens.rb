# frozen_string_literal: true

class CreateAgentApiTokens < ActiveRecord::Migration[6.1]
  def change
    create_table :agent_api_tokens do |t|
      t.references :user, null: false, foreign_key: false, index: true
      t.string :token, null: false
      t.string :name
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :agent_api_tokens, :token, unique: true
  end
end