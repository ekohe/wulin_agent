class AddLifecycleToAgentApiTokens < ActiveRecord::Migration[6.1]
  def change
    add_column :agent_api_tokens, :revoked_at, :datetime
    add_column :agent_api_tokens, :expires_at, :datetime
  end
end