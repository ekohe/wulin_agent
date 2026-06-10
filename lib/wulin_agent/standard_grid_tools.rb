# frozen_string_literal: true

module WulinAgent
  class StandardGridTools
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
          permission: "#{grid.controller}#read"
        ) do |_params, _user|
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

      def build_index(grid)
        tool(
          grid,
          "index",
          description: "List #{grid.controller} records with pagination and filters",
          mutating: false,
          permission: "#{grid.controller}#read"
        ) do |params, user|
          GridDispatcher.call(
            grid.controller,
            "index",
            {
              "offset"   => params["offset"] || 0,
              "count"    => params["count"] || 50,
              "filters"  => params["filters"],
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
          permission: "#{grid.controller}#read"
        ) do |params, user|
          GridDispatcher.call(
            grid.controller,
            "index",
              {"checkbox_record_ids" => params["id"].to_s},
              user
            )
        end
      end

      def build_create(grid)
        tool(
          grid,
          "create",
          description: "Create a new #{grid.controller} record",
          mutating: true,
          permission: "#{grid.controller}#cud"
        ) do |params, user|
          GridDispatcher.call(
            grid.controller,
            "create",
            {"item" => params["attributes"] || params["item"]},
            user
          )
        end
      end

      def build_update(grid)
        tool(
          grid,
          "update",
          description: "Update #{grid.controller} record(s)",
          mutating: true,
          permission: "#{grid.controller}#cud"
        ) do |params, user|
          GridDispatcher.call(
            grid.controller,
            "update",
            {
              "id"   => Array(params["id"] || params["ids"]).join(","),
              "item" => params["attributes"] || params["item"]
            },
            user
          )
        end
      end

      def build_destroy(grid)
        tool(
          grid,
          "destroy",
          description: "Delete a #{grid.controller} record",
          mutating: true,
          permission: "#{grid.controller}#cud"
        ) do |params, user|
          GridDispatcher.call(
            grid.controller,
            "destroy",
            {"id" => Array(params["id"] || params["ids"]).join(",")},
            user
          )
        end
      end



    end
  end
end
