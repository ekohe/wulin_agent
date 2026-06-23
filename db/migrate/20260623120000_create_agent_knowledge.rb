# frozen_string_literal: true

class CreateAgentKnowledge < ActiveRecord::Migration[6.1]
  def change
    create_table :agent_knowledge do |t|
      t.string :key, null: false
      t.text :value, null: false
      t.string :category, null: false
      t.string :scope

      t.timestamps
    end

    add_index :agent_knowledge, :category
    add_index :agent_knowledge, :scope

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          CREATE UNIQUE INDEX index_agent_knowledge_on_key_and_scope
          ON agent_knowledge (key, COALESCE(scope, ''))
        SQL
      end

      dir.down do
        execute "DROP INDEX IF EXISTS index_agent_knowledge_on_key_and_scope"
      end
    end
  end
end
