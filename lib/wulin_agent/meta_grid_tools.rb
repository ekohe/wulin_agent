# frozen_string_literal: true

module WulinAgent
  class MetaGridTools
    CONTROLLER = {
      controller: {
        type: "string",
        description: 'Grid controller name (e.g. "people"). Call list_grids first.'
      }
    }.freeze

    LIST_RECORDS_FIELD = {
      type: "string",
      description: "Column name from get_columns."
    }.freeze

    FILTER_ITEM = {
      type: "object",
      description: "Filter on one column. Call get_columns first to see filterable column names.",
      properties: {
        column: {
          type: "string",
          description: 'Column name from get_columns (e.g. "last_name"). Must be filterable.'
        },
        value: {
          type: "string",
          description: "Value to match. Use % wildcards for text LIKE patterns. Not used when operator is between."
        },
        value_from: {
          type: "string",
          description: "Lower bound when operator is between (inclusive)."
        },
        value_to: {
          type: "string",
          description: "Upper bound when operator is between (inclusive)."
        },
        operator: {
          type: "string",
          enum: %w[
            equals not_equals starts_with include exclude contains
            gte lte gt lt between
          ],
          description: 'Default: "equals". equals — exact on numbers/ids; text prefix only (prefer starts_with). ' \
                       "starts_with — text prefix. include or contains — substring. " \
                       "gte/lte/gt/lt — numeric comparison (integer, float, decimal columns). " \
                       "between — two bounds via value_from and value_to (numeric columns). " \
                       "Date/datetime ranges are not supported."
        }
      },
      required: ["column"]
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
      rescue ActiveRecord::StatementInvalid => e
        {"error" => sql_query_error_message(e)}
      end

      def sql_query_error_message(error)
        message = error.message.to_s
        if message.include?("bind variables")
          "Invalid filter or sort: one or more columns cannot be queried in SQL. " \
            "Call get_columns and use only columns with filterable: true."
        else
          "Database query failed: #{message}"
        end
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
          description: "List columns for a grid. Call before create, update, or filtering. " \
                        "Use filterable column names in list_records filters.",
          mutating: false,
          params_schema: {properties: CONTROLLER, required: ["controller"]}
        ) do |grid, _params, _user|
          model = grid.grid_class.model
          grid.columns.map { |column| ColumnMetadata.serialize(column, model: model) }
        end
      end

      def build_list_records
        make_tool(
          name: "list_records",
          operation: "index",
          description: "List records with optional filters, sorting, and pagination. " \
                        "Call get_columns first — all columns are listed there even if omitted from " \
                        "list responses by host defaults. Pass fields to choose columns (including " \
                        "any omitted by default). Pass omit_columns: [] to return every column. " \
                        "id is included automatically when using fields. Use read_record for one full row.",
          mutating: false,
          params_schema: {
            properties: CONTROLLER.merge(
              offset: {
                type: "integer",
                description: "Number of records to skip. Default: 0."
              },
              count: {
                type: "integer",
                description: "Max records to return. Default: 50."
              },
              filters: {
                type: "array",
                description: 'Filters to apply. Example: [{"column":"last_name","value":"Martin","operator":"equals"}]',
                items: FILTER_ITEM
              },
              sort_col: {
                type: "string",
                description: "Column name to sort by. Must be sortable in get_columns."
              },
              sort_dir: {
                type: "string",
                enum: %w[ASC DESC],
                description: "Sort direction. Default follows the grid configuration."
              },
              fields: {
                type: "array",
                description: "Column names to return. Omit large text columns when listing; use read_record for full text.",
                items: LIST_RECORDS_FIELD
              },
              omit_columns: {
                type: "array",
                description: "Column names to exclude from the response (alternative to fields).",
                items: LIST_RECORDS_FIELD
              },
              row_format: {
                type: "string",
                enum: %w[objects arrays],
                description: "Row shape when projecting: objects (default) or arrays."
              },
              text_max_chars: {
                type: "integer",
                description: "When projecting, truncate long string values to this length (read_record is never truncated)."
              },
              debug: {
                type: "boolean",
                description: "Include sql/query debug metadata in the response. Default: false."
              }
            ),
            required: ["controller"]
          }
        ) do |grid, params, user|
          projection = list_projection_options(grid, params)
          index_params = list_records_index_params(grid, params, projection)
          next index_params if index_params.key?("error")

          result = GridDispatcher.call(grid.controller, "index", index_params, user)
          wrap_list_result(grid, result, params, projection)
        end
      end

      def build_read_record
        make_tool(
          name: "read_record",
          operation: "read",
          description: "Read a single record by id (full row, no text truncation).",
          mutating: false,
          params_schema: {
            properties: CONTROLLER.merge(
              id: {type: "integer", description: "Record id"},
              debug: {
                type: "boolean",
                description: "Include sql/query debug metadata. Default: false."
              }
            ),
            required: ["controller", "id"]
          }
        ) do |grid, params, user|
          id = record_id(params)
          next {"error" => "id is required"} unless id

          result = GridDispatcher.call(grid.controller, "index", {"checkbox_record_ids" => id}, user)
          result = GridListResponse.sanitize_metadata(result, debug: list_records_debug?(params))
          GridResult.wrap(grid, result)
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
                description: "Field values — call get_columns first to see valid fields",
                properties: {}
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
                description: "Fields to update — call get_columns first to see valid fields",
                properties: {}
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

      def wrap_list_result(grid, result, params, projection = nil)
        projection ||= list_projection_options(grid, params)
        result = GridListResponse.sanitize_metadata(result, debug: list_records_debug?(params))
        projected = ListRecordsProjection.apply(
          grid: grid,
          payload: result,
          fields: projection[:fields],
          omit_columns: projection[:omit_columns],
          row_format: projection[:row_format],
          text_max_chars: projection[:text_max_chars]
        )
        return projected if projected.is_a?(Hash) && projected.key?("error")

        GridResult.wrap(grid, projected)
      end

      def list_records_index_params(grid, params, projection)
        filters = normalize_list_filters(params["filters"], grid: grid)
        return filters if filters.is_a?(Hash) && filters.key?("error")

        index = {
          "offset" => params["offset"] || 0,
          "count" => params["count"] || 50,
          "filters" => filters,
          "sort_col" => params["sort_col"],
          "sort_dir" => params["sort_dir"]
        }.compact

        return index unless projection_active?(projection)

        names = ListRecordsProjection.resolve_column_names(
          grid: grid,
          fields: projection[:fields],
          omit_columns: projection[:omit_columns]
        )
        index["agent_fields"] = names.join(",") if names.any?
        index
      end

      def projection_active?(projection)
        projection[:fields]&.any? || projection[:omit_columns]&.any?
      end

      def list_records_debug?(params)
        return params["debug"] if params.key?("debug")

        WulinAgent.config.list_records_debug_metadata
      end

      def list_projection_options(grid, params)
        fields = normalize_column_list(params["fields"])
        omit_columns = normalize_column_list(params["omit_columns"]) if params.key?("omit_columns")
        row_format = params["row_format"]

        text_max_chars = resolve_text_max_chars(params)

        if fields.any?
          return projection_hash(fields: fields, omit_columns: nil, row_format: row_format, text_max_chars: text_max_chars)
        end

        if params.key?("omit_columns")
          return projection_hash(fields: nil, omit_columns: omit_columns, row_format: row_format, text_max_chars: text_max_chars)
        end

        default_omit = WulinAgent.config.default_omit_columns_for(grid.controller)
        if default_omit.any?
          projection_hash(fields: nil, omit_columns: default_omit, row_format: row_format, text_max_chars: text_max_chars)
        else
          projection_hash(fields: nil, omit_columns: nil, row_format: row_format, text_max_chars: text_max_chars)
        end
      end

      def projection_hash(fields:, omit_columns:, row_format:, text_max_chars:)
        {fields: fields, omit_columns: omit_columns, row_format: row_format, text_max_chars: text_max_chars}
      end

      def resolve_text_max_chars(params)
        return Integer(params["text_max_chars"]) if params["text_max_chars"].present?

        WulinAgent.config.list_records_text_max_chars
      rescue ArgumentError, TypeError
        nil
      end

      def normalize_column_list(value)
        Array(value).map(&:to_s).map(&:strip).reject(&:empty?)
      end

      def normalize_list_filters(filters, grid: nil)
        return nil if filters.nil?

        ListRecordsFilterNormalizer.normalize(filters, grid: grid)
      rescue ListRecordsFilterNormalizer::ValidationError => error
        {"error" => error.message}
      end
    end
  end
end
