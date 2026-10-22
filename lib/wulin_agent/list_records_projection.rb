# frozen_string_literal: true

module WulinAgent
  class ListRecordsProjection
    class ValidationError < StandardError; end

    ROW_FORMAT_OBJECTS = "objects"
    ROW_FORMAT_ARRAYS = "arrays"

    def self.apply(grid:, payload:, fields: nil, omit_columns: nil, row_format: nil, text_max_chars: nil)
      new(
        grid: grid,
        fields: fields,
        omit_columns: omit_columns,
        row_format: row_format,
        text_max_chars: text_max_chars
      ).apply(payload)
    end

    def self.resolve_column_names(grid:, fields: nil, omit_columns: nil)
      new(grid: grid, fields: fields, omit_columns: omit_columns).resolve_column_names
    end

    def initialize(grid:, fields: nil, omit_columns: nil, row_format: nil, text_max_chars: nil)
      @grid = grid
      @fields = Array(fields).map(&:to_s).reject(&:empty?)
      @omit_columns = Array(omit_columns).map(&:to_s).reject(&:empty?)
      @row_format = row_format&.to_s
      @text_max_chars = positive_integer(text_max_chars)
    end

    def resolve_column_names
      selected_column_names
    end

    def active?
      @fields.any? || @omit_columns.any?
    end

    def apply(payload)
      return payload unless active?
      return payload unless GridResult.grid_result?(payload)

      names = selected_column_names
      validate!(names)

      rows = Array(payload["rows"]).map { |row| project_row(row, names) }

      payload.merge(
        "rows" => rows,
        "columns" => column_headers_for(names)
      )
    rescue ValidationError => error
      {"error" => error.message}
    end

    private

    def source_columns
      if @grid.respond_to?(:grid_class) && @grid.grid_class
        @grid.grid_class.columns
      else
        @grid.columns
      end
    end

    def all_column_names
      source_columns.map { |col| col.name.to_s }
    end

    def column_index(name)
      source_columns.index { |col| col.name.to_s == name }
    end

    def selected_column_names
      names =
        if @fields.any?
          @fields.dup
        else
          all_column_names - @omit_columns
        end

      if @fields.any? && all_column_names.include?("id") && !names.include?("id")
        names.unshift("id")
      end

      names
    end

    def project_row(row, names)
      truncated_columns = []

      if effective_row_format == ROW_FORMAT_ARRAYS
        return names.map { |name| row[column_index(name)] }
      end

      names.each_with_object({}) do |name, hash|
        index = column_index(name)
        next if index.nil?

        value, truncated = truncate_value(row[index])
        truncated_columns << name if truncated
        hash[name] = value
      end.tap do |hash|
        hash["_truncated_columns"] = truncated_columns if truncated_columns.any?
      end
    end

    def truncate_value(value)
      return [value, false] unless @text_max_chars
      return [value, false] unless value.is_a?(String)
      return [value, false] if value.length <= @text_max_chars

      ["#{value[0, @text_max_chars]}…", true]
    end

    def positive_integer(value)
      return nil if value.nil?

      number = Integer(value)
      number.positive? ? number : nil
    rescue ArgumentError, TypeError
      nil
    end

    def effective_row_format
      return @row_format if [ROW_FORMAT_OBJECTS, ROW_FORMAT_ARRAYS].include?(@row_format)

      ROW_FORMAT_OBJECTS
    end

    def column_headers_for(names)
      names.map do |name|
        col = source_columns.find { |c| c.name.to_s == name }
        {
          "name" => name,
          "label" => col&.label.presence || name.humanize
        }
      end
    end

    def validate!(names)
      if @fields.any? && names.empty?
        raise ValidationError, "fields cannot be empty. Call get_columns or use omit_columns."
      end

      if names.empty?
        raise ValidationError, "No columns selected. Adjust fields or omit_columns."
      end

      unknown = names - all_column_names
      return if unknown.empty?

      raise ValidationError,
        "Unknown column(s): #{unknown.join(', ')}. Valid: #{all_column_names.join(', ')}."
    end
  end
end
