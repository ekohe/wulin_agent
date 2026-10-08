class CreateWulinAgentApprovalGrants < ActiveRecord::Migration[6.1]
  def change
    create_table :agent_approval_grants do |t|
      t.references :user, null: false, foreign_key: false
      t.string :token_digest, null: false
      t.string :tool, null: false
      t.jsonb :params, null: false, default: {}
      t.string :tool_call_id
      t.datetime :expires_at, null: false
      t.datetime :consumed_at

      t.timestamps
    end
    add_index :agent_approval_grants, :token_digest, unique: true
    add_index :agent_approval_grants, :expires_at
  end
end
