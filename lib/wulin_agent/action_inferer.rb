# frozen_string_literal: true

module WulinAgent
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
        controller_class = resolve_controller(grid.controller)
        return unless controller_class.instance_methods(false).include?(operation.to_sym)
        
        StandardGridTools.tool(
          grid,
          operation,
          description: action[:title].presence || "Run #{grid.controller}##{operation}",
          mutating: mutating?(operation),
          permission: "#{grid.controller}##{operation}",
          params_schema: AstParamExtractor.new(controller_class, operation.to_sym).to_schema
        ) do |params, user|
          GridDispatcher.call(grid.controller, operation, params, user)
        end
      end

      def resolve_controller(name)
        "#{name.camelize}Controller".constantize
      end

      def mutating?(operation)
        GridDispatcher.mutating?(operation)
      end

    end
  end

end
