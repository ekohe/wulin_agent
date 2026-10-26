# frozen_string_literal: true

module WulinAgent
  # Maps MCP-friendly filter operators to the Wulin grid filter API before GridDispatcher runs.
  # Text: prefix (equals / starts_with), substring (include / contains).
  # Numeric comparisons: gte/lte/gt/lt embed ">=", "<=", etc. in the value (Wulin convention).
  module ListRecordsFilterNormalizer
    class ValidationError < StandardError; end

    COMPARISON_OPERATORS = {
      "gte" => ">=",
      "lte" => "<=",
      "gt" => ">",
      "lt" => "<"
    }.freeze

    DATE_SQL_TYPES = %w[date datetime].freeze
    EMBEDDED_COMPARISON_PATTERN = /\A(>=|<=|>|<|=)/

    OPERATORS = (
      %w[equals not_equals exclude starts_with contains include between] +
      COMPARISON_OPERATORS.keys
    ).freeze

    module_function

    def normalize(filters, grid: nil)
      return nil if filters.nil?

      output = []
      Array(filters).each do |filter|
        normalized =
          begin
            normalize_one(filter, grid: grid)
          rescue ValidationError => error
            return error_hash(error.message)
          end
        return normalized if error_result?(normalized)

        append_normalized!(output, normalized)
      end
      output
    end

    def append_normalized!(output, normalized)
      if normalized.is_a?(Array)
        output.concat(normalized)
      else
        output << normalized
      end
    end

    def normalize_one(filter, grid: nil)
      unless filter.is_a?(Hash)
        raise ValidationError, "Each filter must be an object with column and value."
      end

      column = filter["column"].to_s
      raise ValidationError, "Filter column is required." if column.empty?

      validate_filterable_column!(grid, column)

      operator = filter["operator"].to_s.presence || "equals"
      validate_operator!(operator)

      return normalize_between(column, filter, grid: grid) if operator == "between"

      value = filter["value"]
      if value.nil?
        raise ValidationError,
          "Filter on \"#{column}\" requires value (or operator between with value_from and value_to)."
      end

      case operator
      when "starts_with"
        grid_filter(column, "equals", value.to_s)
      when "contains", "include"
        grid_filter(column, "include", contains_pattern(value.to_s))
      when *COMPARISON_OPERATORS.keys
        normalize_comparison(column, operator, value, grid: grid)
      when "equals", "not_equals", "exclude"
        grid_filter(column, operator, value.to_s)
      end
    end

    def validate_operator!(operator)
      return if OPERATORS.include?(operator)

      raise ValidationError,
        "Unknown filter operator \"#{operator}\". " \
        "Use equals, include, starts_with, gte, lte, between, etc."
    end

    def validate_filterable_column!(grid, column_name)
      return unless grid

      column = grid.columns.find { |col| col.name.to_s == column_name }
      unless column
        raise ValidationError,
          "Unknown column \"#{column_name}\". Call get_columns and use filterable column names."
      end

      model = grid.respond_to?(:grid_class) ? grid.grid_class&.model : nil
      return if ColumnMetadata.agent_filterable?(column, model: model)

      raise ValidationError,
        "Column \"#{column_name}\" is not filterable. Call get_columns and use only columns with filterable: true."
    end

    def normalize_comparison(column, operator, value, grid:)
      reject_date_range!(column, grid, operator)

      embedded = embed_comparison(value.to_s, COMPARISON_OPERATORS.fetch(operator))
      grid_filter(column, "equals", embedded)
    end

    def normalize_between(column, filter, grid:)
      from = filter["value_from"] || filter["from"]
      to = filter["value_to"] || filter["to"]
      if from.nil? || to.nil?
        return error_hash("between requires value_from and value_to on the filter object.")
      end

      reject_date_range!(column, grid, "between")

      [
        grid_filter(column, "equals", embed_comparison(from.to_s, ">=")),
        grid_filter(column, "equals", embed_comparison(to.to_s, "<="))
      ]
    end

    def reject_date_range!(column, grid, operator)
      sql_type = column_sql_type(grid, column)
      return unless sql_type && DATE_SQL_TYPES.include?(sql_type)

      raise ValidationError,
        "Range filter #{operator} is not supported on date/datetime column \"#{column}\". " \
        "Use sort_col with pagination, or filter a numeric column (e.g. content_length gte)."
    end

    def column_sql_type(grid, column_name)
      return nil unless grid

      column = grid.columns.find { |col| col.name.to_s == column_name }
      column&.sql_type&.to_s
    end

    def embed_comparison(value, symbol)
      stripped = value.strip
      return stripped if stripped.match?(EMBEDDED_COMPARISON_PATTERN)

      "#{symbol}#{stripped}"
    end

    def contains_pattern(value)
      return value if value.include?("%")

      "%#{escape_like(value)}%"
    end

    def escape_like(value)
      if defined?(ActiveRecord::Base) && ActiveRecord::Base.respond_to?(:sanitize_sql_like)
        ActiveRecord::Base.sanitize_sql_like(value)
      else
        value.gsub(/([%_\\])/, '\\\\\1')
      end
    end

    def grid_filter(column, operator, value)
      {"column" => column, "value" => value, "operator" => operator}
    end

    def error_result?(result)
      result.is_a?(Hash) && result.key?("error")
    end

    def error_hash(message)
      {"error" => message}
    end
  end
end
