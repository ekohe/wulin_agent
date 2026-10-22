# frozen_string_literal: true

module WulinAgent
  class StandardGridTools
    ID_SCHEMA = {
      properties: {id: {type: "integer", description: "Record id"}},
      required: ["id"]
    }.freeze

    ATTRIBUTES_SCHEMA = {
      properties: {
        attributes: {
          type: "object",
          description: "Field values — call get_columns first to see valid fields"
        }
      },
      required: ["attributes"]
    }.freeze

    UPDATE_SCHEMA = {
      properties: {
        id: {type: "integer", description: "Record id"},
        attributes: {
          type: "object",
          description: "Fields to update — call get_columns first to see valid fields"
        }
      },
      required: ["id", "attributes"]
    }.freeze

    class << self
      def build(grid)
        tools = []
        tools << build_get_columns(grid)
        tools << build_index(grid)
        tools << build_read(grid)
        tools << build_create(grid) if grid.default_actions["create"]
        tools << build_update(grid) if grid.default_actions["edit"]
        tools << build_destroy(grid) if grid.default_actions["delete"]
        tools.compact
      end

      def tool(grid, operation, description:, mutating:, permission:, params_schema: {}, &block)
        ToolSpec.new(
          name: WulinAgent.tool_name(grid.controller, operation),
          controller: grid.controller,
          operation: operation,
          description: description,
          params_schema: params_schema,
          mutating: mutating,
          permission: permission,
          callable: block
        )
      end

      def build_get_columns(grid)
        tool(
          grid,
          "get_columns",
          description: "List columns for #{grid.controller} grid",
          mutating: false,
          permission: "#{grid.screen_name}#read"
        ) do |_params, _user|
          model = grid.grid_class.model
          grid.columns.map { |column| ColumnMetadata.serialize(column, model: model) }
        end
      end

      def build_index(grid)
        tool(
          grid,
          "index",
          description: "List #{grid.controller} records with pagination and filters",
          mutating: false,
          permission: "#{grid.screen_name}#read"
        ) do |params, user|
          filters = normalize_standard_filters(grid, params["filters"])
          next filters if filters.is_a?(Hash) && filters.key?("error")

          GridDispatcher.call(
            grid.controller,
            "index",
            {
              "offset"   => params["offset"] || 0,
              "count"    => params["count"] || 50,
              "filters"  => filters,
              "sort_col" => params["sort_col"],
              "sort_dir" => params["sort_dir"]
            }.compact,
            user
          )
        end
      end

      def build_read(grid)
        tool(
          grid,
          "read",
          description: "Read a single #{grid.controller} record by id",
          mutating: false,
          permission: "#{grid.screen_name}#read",
          params_schema: ID_SCHEMA
        ) do |params, user|
          id = record_id(params)
          next {"error" => "id is required"} unless id

          GridDispatcher.call(grid.controller, "index", {"checkbox_record_ids" => id}, user)
        end
      end

      def build_create(grid)
        tool(
          grid,
          "create",
          description: "Create a new #{grid.controller} record",
          mutating: true,
          permission: "#{grid.screen_name}#cud",
          params_schema: ATTRIBUTES_SCHEMA
        ) do |params, user|
          attributes = params["attributes"] || params["item"]
          next {"error" => "attributes is required"} if attributes.blank?

          GridDispatcher.call(grid.controller, "create", {"item" => attributes}, user)
        end
      end

      def build_update(grid)
        tool(
          grid,
          "update",
          description: "Update a #{grid.controller} record by id",
          mutating: true,
          permission: "#{grid.screen_name}#cud",
          params_schema: UPDATE_SCHEMA
        ) do |params, user|
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

      def build_destroy(grid)
        tool(
          grid,
          "destroy",
          description: "Delete a #{grid.controller} record by id",
          mutating: true,
          permission: "#{grid.screen_name}#cud",
          params_schema: ID_SCHEMA
        ) do |params, user|
          id = record_id(params)
          next {"error" => "id is required"} unless id

          GridDispatcher.call(grid.controller, "destroy", {"id" => id}, user)
        end
      end

      def record_id(params)
        Array(params["id"] || params["ids"]).map(&:to_s).reject(&:empty?).join(",").presence
      end

      def normalize_standard_filters(grid, filters)
        ListRecordsFilterNormalizer.normalize(filters, grid: grid)
      rescue ListRecordsFilterNormalizer::ValidationError => error
        {"error" => error.message}
      end
    end
  end
end
