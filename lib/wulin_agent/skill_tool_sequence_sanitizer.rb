# frozen_string_literal: true

module WulinAgent
  # Shrinks a distilled tool_sequence into a reusable playbook skeleton:
  # keep workflow structure, drop run-specific payloads (plans, prompt bodies, IDs).
  class SkillToolSequenceSanitizer
    FILTER_KEYS = %w[column operator].freeze

    TOOL_PARAM_KEYS = {
      "list_records" => %w[controller count sort_col sort_dir row_format text_max_chars debug],
      "get_columns" => %w[controller],
      "list_grids" => [],
      "knowledge_search" => %w[category scope],
      "analyze_config_flow" => [],
      "provision_prompt_config" => %w[dry_run],
      "provision_routine_config" => %w[dry_run],
      "skill_read" => %w[name],
      "render_chart" => []
    }.freeze

    DEFAULT_PARAM_KEYS = %w[controller dry_run count sort_col sort_dir category scope].freeze

    REDACT_PARAM_KEYS = %w[
      plan prompt body input content message text arguments data payload
    ].freeze

    MAX_STRING_LENGTH = 120

    def self.sanitize_sequence(steps)
      dedupe_consecutive(
        Array(steps).filter_map { |step| sanitize_step(step) }
      )
    end

    def self.sanitize_step(step)
      return unless step.is_a?(Hash)

      tool = step["tool"].to_s.strip
      return if tool.empty?

      params = sanitize_params(step["params"] || {}, tool: tool)
      {"tool" => tool, "params" => params}
    end

    def self.sanitize_params(params, tool:)
      return {} unless params.is_a?(Hash)

      allowed = TOOL_PARAM_KEYS.fetch(tool, DEFAULT_PARAM_KEYS)
      output = {}

      allowed.each do |key|
        value = params[key]
        next if value.nil?

        output[key] = sanitize_value(key, value)
      end

      filters = params["filters"]
      if filters.is_a?(Array) && !filters.empty?
        output["filters"] = sanitize_filters(filters)
      end

      %w[fields omit_columns].each do |key|
        value = params[key]
        next unless value.is_a?(Array) && value.all? { |item| item.is_a?(String) }

        output[key] = value.map(&:to_s).reject(&:empty?).first(20)
      end

      output.reject { |_, value| value.nil? }
    end

    def self.sanitize_filters(filters)
      Array(filters).filter_map do |filter|
        next unless filter.is_a?(Hash)

        entry = FILTER_KEYS.each_with_object({}) do |key, memo|
          value = filter[key]
          next if value.nil? || value.to_s.strip.empty?

          memo[key] = value
        end
        entry unless entry.empty?
      end
    end

    def self.sanitize_value(key, value)
      return sanitize_params(value, tool: key) if value.is_a?(Hash) && REDACT_PARAM_KEYS.include?(key.to_s)

      case value
      when String
        return value if value.length <= MAX_STRING_LENGTH

        nil
      when TrueClass, FalseClass, Integer, Float
        value
      when Array
        return value if value.length <= 5 && value.all? { |item| primitive?(item) }

        nil
      else
        nil
      end
    end

    def self.primitive?(value)
      value.is_a?(String) || value.is_a?(Numeric) || value == true || value == false || value.nil?
    end

    def self.dedupe_consecutive(steps)
      steps.each_with_object([]) do |step, memo|
        memo << step unless memo.last == step
      end
    end
  end
end
