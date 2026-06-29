# frozen_string_literal: true

require "mcp"

module WulinAgent
  class McpAdapter
    def self.build(tool_specs, user:, approval_mode: :auto)
      tool_specs.map { |spec| wrap(spec, user: user, approval_mode: approval_mode) }
    end   
    
    def self.wrap(tool_spec, user:, approval_mode:)
      schema = normalize_schema(tool_spec.params_schema)
      input_schema = {properties: schema[:properties]}
      input_schema[:required] = schema[:required] if schema[:required].any?

      MCP::Tool.define(
        name: tool_spec.name,
        description: tool_spec.description,
        input_schema: input_schema,
        annotations: {
          read_only_hint: !tool_spec.mutating,
          destructive_hint: tool_spec.mutating
        }
      ) do |args, server_context:|
          result = tool_spec.execute(
            args.deep_stringify_keys,
            user,
            approval_mode: approval_mode,
            approved: false
          )
          MCP::Tool::Response.new([{type: "text", text: result.to_json}])
        end
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