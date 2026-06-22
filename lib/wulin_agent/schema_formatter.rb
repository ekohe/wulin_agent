# frozen_string_literal: true

module WulinAgent
  class SchemaFormatter
    class << self
      def format(schema)
        schema = normalize(schema)
        properties = schema[:properties]
        required = Array(schema[:required]).map(&:to_sym)

        return "(no params)" if properties.empty?

        properties.map do |name, spec|
          part = "#{name}: #{type_label(spec)}"
          part += " (required)" if required.include?(name.to_sym)
          part
        end.join(", ")
      end

      private

      def normalize(schema)
        return {properties: {}, required: []} if schema.blank?

        {
          properties: (schema[:properties] || schema["properties"] || {}).deep_symbolize_keys,
          required: schema[:required] || schema["required"] || []
        }
      end

      def type_label(spec)
        spec = spec.deep_symbolize_keys if spec.respond_to?(:deep_symbolize_keys)
        type = spec[:type].to_s

        if type == "array" && spec.dig(:items, :type)
          "array<#{spec.dig(:items, :type)}>"
        else
          type.presence || "unknown"
        end
      end
    end
  end
end