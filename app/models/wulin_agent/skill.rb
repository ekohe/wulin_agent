# frozen_string_literal: true

module WulinAgent
  class Skill < ApplicationRecord
    self.table_name = "agent_skills"

    validates :name, presence: true, uniqueness: {case_sensitive: false}
    validates :description, presence: true
    validates :instructions, presence: true

    # Name + description of every skill — injected into the system prompt
    # so the agent knows which playbooks exist (instructions fetched on demand).
    PROMPT_LIMIT = 30

    def self.for_prompt(limit: PROMPT_LIMIT)
      return [] unless table_exists?

      order(:name).limit(limit).pluck(:name, :description)
    end

    def self.table_exists?
      connection.data_source_exists?(table_name)
    end
  end
end
