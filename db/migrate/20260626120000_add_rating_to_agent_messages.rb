# frozen_string_literal: true

class AddRatingToAgentMessages < ActiveRecord::Migration[6.1]
  def change
    add_column :agent_messages, :rating, :string
  end
end
