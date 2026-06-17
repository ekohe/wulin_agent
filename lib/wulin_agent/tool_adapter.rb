# frozen_string_literal: true

require "ruby_llm"

module WulinAgent
  class ToolAdapter
    def self.build(tool_specs, user:, approval_mode: :confirm_writes)
      tool_specs.map { |spec| wrap(spec, user: user, approval_mode: approval_mode) }
    end   
    
    def self.wrap(tool_spec, user:, approval_mode:)
      schema = normalize_schema(tool_spec.params_schema)
      klass = Class.new(RubyLLM::Tool) do
        desc tool_spec.description
        params type: "object",
          properties: schema[:properties],
          required: schema[:required]

        define_method(:name) { tool_spec.name }

        define_method(:execute) do |**kwargs|
          result = tool_spec.execute(
            kwargs.stringify_keys,
            user,
            approval_mode: approval_mode,
            approved: false
          )
          if result.is_a?(Hash) && result["status"] == "approval_required"
            halt(result)
          else
            result
          end
        end
      end

      klass.new     
    end

    def self.normalize_schema(params_schema)
      return {properties: {}, required: []} if params_schema.nil? || params_schema.empty?

      {
        properties: params_schema[:properties] || {},
        required: params_schema[:required] || []
      }
    end

    private_class_method :wrap, :normalize_schema
  end
end