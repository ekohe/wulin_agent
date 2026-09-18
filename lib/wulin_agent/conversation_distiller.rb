# frozen_string_literal: true

module WulinAgent
  # Extracts successful tool steps from an assistant turn for skill distillation.
  class ConversationDistiller
    SKIP_STATUSES = %w[approval_required rejected].freeze

    def self.steps_from(message)
      turn_messages(message).flat_map { |m| steps_for_message(m) }
    end

    # Raw steps with run-specific params — useful for debugging only.
    def self.raw_steps_from(message)
      steps_from(message)
    end

    # Sanitized sequence safe to persist on agent_skills and return from skill_read.
    def self.skill_steps_from(message)
      SkillToolSequenceSanitizer.sanitize_sequence(steps_from(message))
    end

    # Les messages assistant du tour courant : du message noté jusqu'au
    # dernier message user (utile car un flux avec approbation est coupé en
    # plusieurs messages assistant : les tool_calls vivent sur le premier).
    def self.turn_messages(message)
      return [message] unless message.respond_to?(:conversation)

      msgs = message.conversation.messages.chronological.to_a
      idx = msgs.index { |m| m.id == message.id } || (msgs.length - 1)
      start = idx
      start -= 1 while start.positive? && msgs[start - 1].role == "assistant"
      msgs[start..idx].select { |m| m.role == "assistant" }
    end

    def self.steps_for_message(message)
      metadata = message.metadata || {}
      calls = metadata["tool_calls"] || []
      results_by_id = (metadata["tool_results"] || []).each_with_object({}) do |entry, memo|
        memo[entry["id"]] = entry
      end

      calls.filter_map do |call|
        result = results_by_id[call["id"]]&.dig("result")
        next unless successful?(result)

        {"tool" => call["name"], "params" => call["arguments"] || {}}
      end
    end

    def self.successful?(result)
      return false if result.nil?
      return true unless result.is_a?(Hash)

      return false if result["error"].to_s != ""
      return false if SKIP_STATUSES.include?(result["status"])
      return false if result.key?("success") && !result["success"]

      true
    end
  end
end
