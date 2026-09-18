# frozen_string_literal: true

module WulinAgent
  class SkillDistiller
    SYSTEM = <<~PROMPT
      You turn a successful tool workflow into a reusable skill (playbook).
      Reply with STRICT JSON only, no prose, no markdown fences:
      {
        "reusable": true|false,
        "name": "snake_case_id",
        "description": "one line: when to use it",
        "instructions": "markdown steps",
        "tool_sequence": [{"tool": "tool_name", "params": {}}]
      }

      Rules:
      - Set "reusable": false if the task is too trivial or one-off to save.
      - instructions: generic workflow. Do not embed large JSON plans or prompt bodies.
      - tool_sequence: optional abstract replay of the workflow. Omit large payloads
        (plans, prompt text, record IDs). Use {} when values come from the user request.
        Keep only structural params such as controller, dry_run, filter column/operator.
      - If tool_sequence would not help, return [].
    PROMPT

    def self.call(message:, user:)
      new(message, user).call
    end

    def initialize(message, user)
      @message = message
      @user = user
    end

    def call
      steps = ConversationDistiller.skill_steps_from(@message)
      return if steps.empty?

      data = ask_llm(steps)
      return unless data && data["reusable"]

      WulinAgent::Skill.create!(
        name: unique_name(data["name"]),
        description: data["description"],
        instructions: data["instructions"],
        tool_sequence: tool_sequence_for_skill(data, steps),
        created_by: @user.id
      )
    rescue => e
      Rails.logger.error("[wulin_agent] distill failed: #{e.class}: #{e.message}")
      nil
    end

    private

    def ask_llm(steps)
      prompt = "User request: #{request_text}\nSanitized tool sequence (JSON): #{steps.to_json}"
      Rails.logger.info("[skill_distiller] >>> prompt:\n#{prompt}")
      response = RubyLLM.chat(model: RubyLLM.config.default_model)
        .with_instructions(SYSTEM)
        .ask(prompt)
      Rails.logger.info("[skill_distiller] <<< response: #{response.content}")
      JSON.parse(response.content.to_s.gsub(/\A```json|\A```|```\z/, "").strip)
    rescue JSON::ParserError
      nil
    end

    def tool_sequence_for_skill(data, fallback_steps)
      from_llm = SkillToolSequenceSanitizer.sanitize_sequence(data["tool_sequence"])
      from_llm.presence || fallback_steps
    end

    def request_text
      msgs = @message.conversation.messages.chronological.to_a
      idx = msgs.index(@message) || msgs.length
      msgs[0...idx].reverse.find { |m| m.role == "user" }&.content
    end

    def unique_name(name)
      base = name.to_s.parameterize(separator: "_").presence || "skill"
      candidate = base
      i = 2
      while WulinAgent::Skill.where("name ILIKE ?", candidate).exists?
        candidate = "#{base}_#{i}"
        i += 1
      end
      candidate
    end
  end
end
