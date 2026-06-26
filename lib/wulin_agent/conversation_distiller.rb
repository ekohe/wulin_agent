# frozen_string_literal: true

module WulinAgent
  # Extrait la séquence de tools réussis d'UN message assistant,
  # au format attendu par skill_create (tool_sequence). 100% déterministe.
  class ConversationDistiller
    SKIP_STATUSES = %w[approval_required rejected].freeze

    def self.steps_from(message)
      metadata = message.metadata || {}
      calls = metadata["tool_calls"] || []
      results_by_id = (metadata["tool_results"] || []).index_by { |r| r["id"] }

      calls.filter_map do |call|
        result = results_by_id[call["id"]]&.dig("result")
        next unless successful?(result)

        {"tool" => call["name"], "params" => call["arguments"] || {}}
      end
    end

    def self.successful?(result)
      return false if result.nil?
      return true unless result.is_a?(Hash) # ex: tableau de records => succès

      return false if result["error"].present?
      return false if SKIP_STATUSES.include?(result["status"])

      true
    end
  end
end