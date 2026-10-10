# frozen_string_literal: true

module WulinAgent
  module GridResult
    module_function

    def wrap(grid, payload)
      return payload unless grid_result?(payload)

      payload.merge(
        "columns" => column_headers(grid),
        "display" => "grid"
      )
    end

    def grid_result?(payload)
      payload.is_a?(Hash) &&
        payload["rows"].is_a?(Array) &&
        payload.key?("total")
    end

    def column_headers(grid)
      grid.columns.map do |col|
        {
          "name" => col.name.to_s,
          "label" => col.label.presence || col.name.to_s.humanize
        }
      end
    end
  end
end
