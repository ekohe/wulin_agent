# frozen_string_literal: true

module WulinAgent
  class ToolSchemaError < StandardError; end

  # Builds ToolSpec entries for grid custom actions (non-CRUD).
  #
  # Flow (next implementation):
  #   1. Read Catalog.custom_actions per grid (e.g. :greet on PersonGrid)
  #   2. Resolve PeopleController#greet via AST (RubyVM::AbstractSyntaxTree)
  #   3. Extract params[:name], params[:id], etc. → JSON schema for the LLM
  #   4. Return ToolSpec(name: "people__greet", permission: "people#greet", ...)
  #      that calls GridDispatcher.call(controller, "greet", params, user)
  #
  # Skip UI-only actions with no controller method (e.g. :fullscreen → JS only).
  class ActionInferer
    class << self
      def build(grid)
        grid.custom_actions.filter_map do |action|
          build_tool(grid, action)
        end
      end

      private

      def build_tool(grid, action)
        operation = action[:name].to_s
        controller_class = grid.controller_class
        return unless controller_class
        return unless controller_action?(controller_class, operation)

        decl = agent_action_for(grid, operation)

        ToolSpec.new(
          name: WulinAgent.tool_name(grid.controller, operation),
          controller: grid.controller,
          operation: operation,
          description: resolve_description(grid, action, decl, operation),
          params_schema: resolve_params_schema_with_context(grid, controller_class, operation, decl),
          mutating: resolve_mutating(operation, decl),
          permission: "#{grid.controller}##{operation}",
          callable: ->(params, user) { GridDispatcher.call(grid.controller, operation, params, user) }
        )
      rescue ToolSchemaError
        raise
      rescue => e
        raise tool_schema_error(grid, operation, e)
      end

      def controller_action?(controller_class, operation)
        method = controller_class.instance_method(operation)
        owner = method.owner
        owner == controller_class || owner.in?(controller_class.included_modules)
      rescue NameError
        false
      end

      def mutating?(operation)
        GridDispatcher.mutating?(operation)
      end

      def agent_action_for(grid, operation)
        return unless grid.grid_class.respond_to?(:agent_actions_pool)
        grid.grid_class.agent_actions_pool.find { |decl| decl[:name].to_s == operation.to_s }
      end

      def params_schema_from_declaration(params)
        properties = {}
        required = []
        params.each do |key, spec|
          spec = {type: spec} unless spec.is_a?(Hash)
          properties[key] = {type: spec[:type].to_s}
          required << key if spec[:required]
        end

        {properties: properties, required: required.uniq}
      end

      def resolve_params_schema_with_context(grid, controller_class, operation, decl)
        if decl && decl[:params].present?
          params_schema_from_declaration(decl[:params])
        else
          AstParamExtractor.new(controller_class, operation.to_sym).to_schema
        end
      rescue TypeError, ArgumentError => e
        raise tool_schema_error(grid, operation, e)
      end

      def resolve_description(grid, action, decl, operation)
        decl&.dig(:description).presence ||
          action[:title].presence ||
          "Run #{grid.controller}##{operation}"
      end

      def resolve_mutating(operation, decl)
        return decl[:mutating] if decl&.key?(:mutating)

        mutating?(operation)
      end

      def tool_schema_error(grid, operation, cause = nil)
        tool_name = WulinAgent.tool_name(grid.controller, operation)

        hint = <<~HINT.squish
          Add an explicit agent_action :#{operation} on #{grid.grid_class.name}
          with params: { ... } (see README), or implement #{grid.controller_class.name}##{operation}
          with inferrable params[:...] in Ruby source.
        HINT

        ToolSchemaError.new(
          "Cannot build agent tool #{tool_name} for grid action :#{operation} on #{grid.grid_class.name}. #{hint}"
        )
      end
    end
  end
end
