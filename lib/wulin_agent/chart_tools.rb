# frozen_string_literal: true

module WulinAgent
  class ChartTools
    TYPES = %w[bar line pie].freeze

    DATA_ITEM = {
      type: "object",
      description: "One data point.",
      properties: {
        label: {
          type: "string",
          description: 'Category shown on the X axis (or pie slice), e.g. "Match 1".'
        },
        value: {
          type: "number",
          description: "Numeric value for this point (bar height / line point / slice size)."
        },
        series: {
          type: "string",
          description: "Optional series name for grouped bars / multi-line charts."
        }
      },
      required: %w[label value]
    }.freeze

    class << self
      def build
        [build_render_chart]
      end

      private

      def build_render_chart
        ToolSpec.new(
          name: "render_chart",
          controller: nil,
          operation: "render_chart",
          description: "Display a chart in the chat from data you have ALREADY aggregated. " \
                        "First fetch rows with list_records, aggregate them yourself, then call " \
                        "this with the computed data. Never invent numbers. Supports bar, line, pie.",
          mutating: false,
          permission: nil,
          params_schema: {
            properties: {
              type: {
                type: "string",
                enum: TYPES,
                description: "Chart type: bar, line, or pie."
              },
              title: {
                type: "string",
                description: "Title shown above the chart."
              },
              data: {
                type: "array",
                description: 'Aggregated points. Example: [{"label":"Match 1","value":12}]',
                items: DATA_ITEM
              },
              x: {type: "string", description: 'Optional X axis label (default "label").'},
              y: {type: "string", description: 'Optional Y axis label (default "value").'}

            },
            required: %w[type data]
          },
          callable: ->(params, _user) { render_chart(params) }
        )
      end

      def render_chart(params)
        type = params["type"].to_s
        return {"error" => "type must be one of #{TYPES.join(", ")}"} unless TYPES.include?(type)
        data = normalize_data(params["data"])
        return {"error" => "data must be a non-empty array of {label, value}"} if data.empty?
        {
          "display" => "chart",
          "type" => type,
          "title" => params["title"].to_s,
          "data" => data,
          "x" => params["x"].presence || "label",
          "y" => params["y"].presence || "value"
        }
      end

      def normalize_data(raw)
        Array(raw).filter_map do |point|
          next unless point.is_a?(Hash)
          label = point["label"]
          value = point["value"]
          next if label.blank? || value.nil?
          item = {"label" => label.to_s, "value" => numeric(value)}
          item["series"] = point["series"].to_s if point["series"].present?
          item
        end
      end

      def numeric(value)
        Float(value)
      rescue ArgumentError, TypeError
        value
      end
    end
  end
end
