# frozen_string_literal: true

class AddToolSequenceAndCreatedByToAgentSkills < ActiveRecord::Migration[6.1]
  def change
    add_column :agent_skills, :tool_sequence, :jsonb, null: false, default: []
    add_column :agent_skills, :created_by, :bigint
  end
end
