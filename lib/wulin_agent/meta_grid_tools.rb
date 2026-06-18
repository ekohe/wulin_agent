# frozen_string_literal: true

module WulinAgent
  class MetaGridTools
    CONTROLLER = {
      controller: {
        type: "string",
        description: 'Grid controller name (e.g. "people"). Call list_grids first.'
      }
    }.freeze

    class << self
      def build
        [
          build_list_grids,
          build_get_columns,
          build_list_records,
          build_read_record,
          build_create_record,
          build_update_record,
          build_destroy_record
        ]
      end

      private

      def make_tool(name:, operation:, description:, mutating:, params_schema:, &block)
        ToolSpec.new(
          name: name,
          controller: nil,
          operation: operation,
          description: description,
          mutating: mutating,
          permission: nil,
          params_schema: params_schema,
          callable: ->(params, user) { dispatch(user, operation, params, &block) }
        )
      end

      def dispatch(user, operation, params, &block)
        return {"error" => "controller is required"} if params["controller"].blank?

        grid = GridAccess.find_grid!(params["controller"])
        GridAccess.authorize!(user, grid, operation)
        return {"error" => "#{operation} not available on #{grid.controller}"} unless GridAccess.operation_available?(grid, operation)

        block.call(grid, params, user)
      rescue GridAccess::Error => e
        {"error" => e.message}
      end

      def build_list_grids
        ToolSpec.new(
          name: "list_grids",
          controller: nil,
          operation: "list_grids",
          description: "List grids the user can access.",
          mutating: false,
          permission: nil,
          params_schema: {},
          callable: ->(_params, user) {
            GridAccess.accessible_grids(user).map { |grid| {controller: grid.controller} }
          }
        )
      end

      def build_get_columns
        make_tool(
          name: "get_columns",
          operation: "get_columns",
          description: "List columns for a grid. Call before create or update.",
          mutating: false,
          params_schema: {properties: CONTROLLER, required: ["controller"]}
        ) do |grid, _params, _user|
          grid.columns.map do |column|
            {
              name: column.name.to_s,
              label: column.label,
              sql_type: column.sql_type.to_s,
              filterable: column.filterable,
              sortable: column.sortable,
              choices: column.choices
            }
          end
        end
      end

      def build_list_records
        make_tool(
          name: "list_records",
          operation: "index",
          description: "List records with pagination and filters.",
          mutating: false,
          params_schema: {
            properties: CONTROLLER.merge(
              offset: {type: "integer"},
              count: {type: "integer"},
              filters: {type: "array"},
              sort_col: {type: "string"},
              sort_dir: {type: "string"}
            ),
            required: ["controller"]
          }
        ) do |grid, params, user|
          GridDispatcher.call(
            grid.controller,
            "index",
            {
              "offset" => params["offset"] || 0,
              "count" => params["count"] || 50,
              "filters" => params["filters"],
              "sort_col" => params["sort_col"],
              "sort_dir" => params["sort_dir"]
            }.compact,
            user
          )
        end
      end

      def build_read_record
        make_tool(
          name: "read_record",
          operation: "read",
          description: "Read a single record by id.",
          mutating: false,
          params_schema: {
            properties: CONTROLLER.merge(id: {type: "integer", description: "Record id"}),
            required: ["controller", "id"]
          }
        ) do |grid, params, user|
          id = record_id(params)
          next {"error" => "id is required"} unless id

          GridDispatcher.call(grid.controller, "index", {"checkbox_record_ids" => id}, user)
        end
      end

      def build_create_record
        make_tool(
          name: "create_record",
          operation: "create",
          description: "Create a record. Call get_columns first to see valid fields.",
          mutating: true,
          params_schema: {
            properties: CONTROLLER.merge(
              attributes: {
                type: "object",
                description: "Field values — call get_columns first to see valid fields"
              }
            ),
            required: ["controller", "attributes"]
          }
        ) do |grid, params, user|
          attributes = params["attributes"] || params["item"]
          next {"error" => "attributes is required"} if attributes.blank?

          GridDispatcher.call(grid.controller, "create", {"item" => attributes}, user)
        end
      end

      def build_update_record
        make_tool(
          name: "update_record",
          operation: "update",
          description: "Update a record by id.",
          mutating: true,
          params_schema: {
            properties: CONTROLLER.merge(
              id: {type: "integer", description: "Record id"},
              attributes: {
                type: "object",
                description: "Fields to update — call get_columns first to see valid fields"
              }
            ),
            required: ["controller", "id", "attributes"]
          }
        ) do |grid, params, user|
          id = record_id(params)
          next {"error" => "id is required"} unless id

          attributes = params["attributes"] || params["item"]
          next {"error" => "attributes is required"} if attributes.blank?

          GridDispatcher.call(
            grid.controller,
            "update",
            {"id" => id, "item" => attributes},
            user
          )
        end
      end

      def build_destroy_record
        make_tool(
          name: "destroy_record",
          operation: "destroy",
          description: "Delete a record by id.",
          mutating: true,
          params_schema: {
            properties: CONTROLLER.merge(id: {type: "integer", description: "Record id"}),
            required: ["controller", "id"]
          }
        ) do |grid, params, user|
          id = record_id(params)
          next {"error" => "id is required"} unless id

          GridDispatcher.call(grid.controller, "destroy", {"id" => id}, user)
        end
      end

      def record_id(params)
        Array(params["id"] || params["ids"]).map(&:to_s).reject(&:empty?).join(",").presence
      end
    end
  end
end
