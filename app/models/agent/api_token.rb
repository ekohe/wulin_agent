# frozen_string_literal: true

module Agent
  class ApiToken < ApplicationRecord
    self.table_name = "agent_api_tokens"

    belongs_to :user

    has_secure_token :token
  end
end