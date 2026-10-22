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
      return unless filter.is_a?(Hash)

      column = filter["column"].to_s
      return if column.empty?

      operator = filter["operator"].to_s.presence || "equals"

      return normalize_between(column, filter, grid: grid) if operator == "between"

      value = filter["value"]
      return if value.nil?

      case operator
      when "starts_with"
        grid_filter(column, "equals", value.to_s)
      when "contains", "include"
        grid_filter(column, "include", contains_pattern(value.to_s))
      when *COMPARISON_OPERATORS.keys
        normalize_comparison(column, operator, value, grid: grid)
      when "equals", "not_equals", "exclude"
        grid_filter(column, operator, value.to_s)
      else
        grid_filter(column, operator, value.to_s)
      end
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
