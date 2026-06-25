# frozen_string_literal: true

class CreateAgentSkills < ActiveRecord::Migration[6.1]
  def change
    create_table :agent_skills do |t|
      t.string :name, null: false
      t.text :description, null: false
      t.text :instructions, null: false
      t.integer :usage_count, null: false, default: 0

      t.timestamps
    end

    add_index :agent_skills, :name, unique: true
  end
end
