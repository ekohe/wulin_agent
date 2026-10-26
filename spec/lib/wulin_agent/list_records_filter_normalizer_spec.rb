# frozen_string_literal: true

require "rails_helper"
require "wulin_agent/list_records_filter_normalizer"

RSpec.describe WulinAgent::ListRecordsFilterNormalizer do
  describe ".normalize" do
    it "returns nil when filters are nil" do
      expect(described_class.normalize(nil)).to be_nil
    end

    it "maps starts_with to grid equals" do
      result = described_class.normalize(
        [{"column" => "title", "value" => "Semi", "operator" => "starts_with"}]
      )

      expect(result).to eq(
        [{"column" => "title", "value" => "Semi", "operator" => "equals"}]
      )
    end

    it "wraps include values for substring search" do
      result = described_class.normalize(
        [{"column" => "content", "value" => "技术目录", "operator" => "include"}]
      )

      expect(result.first["operator"]).to eq("include")
      expect(result.first["value"]).to eq("%技术目录%")
    end

    it "treats contains like include" do
      result = described_class.normalize(
        [{"column" => "content", "value" => "foo", "operator" => "contains"}]
      )

      expect(result.first).to include("operator" => "include", "value" => "%foo%")
    end

    it "does not wrap include when the value already has %" do
      result = described_class.normalize(
        [{"column" => "content", "value" => "%40%tech%", "operator" => "include"}]
      )

      expect(result.first["value"]).to eq("%40%tech%")
    end

    it "passes equals through unchanged" do
      result = described_class.normalize(
        [{"column" => "status", "value" => "2", "operator" => "equals"}]
      )

      expect(result).to eq(
        [{"column" => "status", "value" => "2", "operator" => "equals"}]
      )
    end

    it "defaults operator to equals" do
      result = described_class.normalize([{"column" => "id", "value" => "12"}])

      expect(result.first["operator"]).to eq("equals")
    end

    it "escapes LIKE metacharacters in wrapped values" do
      result = described_class.normalize(
        [{"column" => "content", "value" => "a_b", "operator" => "include"}]
      )

      expect(result.first["value"]).to eq("%#{ActiveRecord::Base.sanitize_sql_like("a_b")}%")
    end

    it "embeds gte/lte for numeric comparison" do
      gte = described_class.normalize([{"column" => "content_length", "value" => "800", "operator" => "gte"}])
      lte = described_class.normalize([{"column" => "content_length", "value" => "5000", "operator" => "lte"}])

      expect(gte).to eq(
        [{"column" => "content_length", "value" => ">=800", "operator" => "equals"}]
      )
      expect(lte.first["value"]).to eq("<=5000")
    end

    it "does not double-embed when the value already has a comparison prefix" do
      result = described_class.normalize(
        [{"column" => "age", "value" => ">=30", "operator" => "gte"}]
      )

      expect(result.first["value"]).to eq(">=30")
    end

    it "expands between into gte and lte filters" do
      result = described_class.normalize(
        [
          {
            "column" => "age",
            "operator" => "between",
            "value_from" => "18",
            "value_to" => "65"
          }
        ]
      )

      expect(result).to eq(
        [
          {"column" => "age", "value" => ">=18", "operator" => "equals"},
          {"column" => "age", "value" => "<=65", "operator" => "equals"}
        ]
      )
    end

    it "returns an error when between is missing bounds" do
      result = described_class.normalize(
        [{"column" => "age", "operator" => "between", "value_from" => "1"}]
      )

      expect(result["error"]).to include("value_from", "value_to")
    end

    it "returns an error when column is missing" do
      result = described_class.normalize([{"value" => "x"}])

      expect(result["error"]).to include("column is required")
    end

    it "returns an error when value is missing" do
      result = described_class.normalize([{"column" => "title"}])

      expect(result["error"]).to include("requires value")
    end

    it "returns an error for an unknown operator" do
      result = described_class.normalize(
        [{"column" => "title", "value" => "x", "operator" => "regex"}]
      )

      expect(result["error"]).to include("Unknown filter operator")
    end

    it "returns an error for an unknown column when grid is given" do
      grid = double("grid", columns: [], grid_class: double(model: nil))

      result = described_class.normalize(
        [{"column" => "nope", "value" => "1"}],
        grid: grid
      )

      expect(result["error"]).to include("Unknown column", "nope")
    end

    it "rejects date range operators when grid column is datetime" do
      column = double(
        name: :published_at,
        sql_type: :datetime,
        filterable: true,
        table_column?: true
      )
      grid = double("grid", columns: [column], grid_class: double(model: nil))

      result = described_class.normalize(
        [{"column" => "published_at", "value" => "2026-10-15", "operator" => "gte"}],
        grid: grid
      )

      expect(result["error"]).to include("not supported", "published_at")
    end
  end
end
