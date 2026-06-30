# frozen_string_literal: true

module WulinAgent
  class Knowledge < ApplicationRecord
    self.table_name = "agent_knowledge"

    CATEGORIES = %w[acronym schema goal glossary].freeze

    validates :key, presence: true
    validates :value, presence: true
    validates :category, inclusion: {in: CATEGORIES}
    validates :key, uniqueness: {scope: :scope, case_sensitive: false}

    scope :by_category, ->(category) { where(category: category) }
    scope :for_scope, ->(scope_name) {
      if scope_name.blank?
        where(scope: [nil, ""])
      else
        where(scope: [nil, "", scope_name])
      end
    }

    def self.upsert_entry(key:, value:, category:, scope: nil)
      record = find_or_initialize_by(key: key, scope: scope.presence)
      record.assign_attributes(value: value, category: category)
      record.save!
      record
    end

    def global?
      scope.blank?
    end

    # Global acronyms only — injected into the system prompt (see Runner).
    PROMPT_LIMIT = 30

    def self.for_prompt(limit: PROMPT_LIMIT)
      return [] unless table_exists?

      where(category: "acronym", scope: [nil, ""])
        .order(:key)
        .limit(limit)
        .pluck(:key, :value)
    end

    def self.table_exists?
      connection.data_source_exists?(table_name)
    end
  end
end
