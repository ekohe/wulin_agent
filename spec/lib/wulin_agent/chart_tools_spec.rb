# frozen_string_literal: true

require "rails_helper"

RSpec.describe WulinAgent::ChartTools do
  def tool
    described_class.build.find { |t| t.name == "render_chart" }
  end

  it "exposes a single render_chart tool" do
    names = described_class.build.map(&:name)

    expect(names).to eq(["render_chart"])
  end

  it "is not mutating" do
    expect(tool.mutating).to be(false)
  end

  it "requires type and data in the params schema" do
    expect(tool.params_schema[:required]).to contain_exactly("type", "data")
  end

  it "runs without approval even under confirm_writes" do
    result = tool.execute(
      {"type" => "bar", "data" => [{"label" => "A", "value" => 1}]},
      nil,
      approval_mode: :confirm_writes
    )

    expect(result["status"]).not_to eq("approval_required")
    expect(result["display"]).to eq("chart")
  end

  describe "returning a chart spec" do
    it "wraps aggregated data into a chart spec with default axes" do
      result = tool.execute(
        {
          "type" => "bar",
          "title" => "Ages",
          "data" => [{"label" => "25", "value" => 4}, {"label" => "30", "value" => 5}]
        },
        nil
      )

      expect(result).to eq(
        "display" => "chart",
        "type" => "bar",
        "title" => "Ages",
        "data" => [
          {"label" => "25", "value" => 4.0},
          {"label" => "30", "value" => 5.0}
        ],
        "x" => "label",
        "y" => "value"
      )
    end

    it "keeps custom x and y axis labels" do
      result = tool.execute(
        {
          "type" => "line",
          "data" => [{"label" => "Jan", "value" => 1}],
          "x" => "Month",
          "y" => "Sales"
        },
        nil
      )

      expect(result["x"]).to eq("Month")
      expect(result["y"]).to eq("Sales")
    end

    it "coerces numeric strings to numbers" do
      result = tool.execute(
        {"type" => "pie", "data" => [{"label" => "A", "value" => "12"}]},
        nil
      )

      expect(result["data"]).to eq([{"label" => "A", "value" => 12.0}])
    end

    it "preserves the optional series key for grouped data" do
      result = tool.execute(
        {
          "type" => "bar",
          "data" => [
            {"label" => "M1", "value" => 3, "series" => "NHK"},
            {"label" => "M1", "value" => 2, "series" => "BBC"}
          ]
        },
        nil
      )

      expect(result["data"]).to eq([
        {"label" => "M1", "value" => 3.0, "series" => "NHK"},
        {"label" => "M1", "value" => 2.0, "series" => "BBC"}
      ])
    end

    it "drops points without a label or value" do
      result = tool.execute(
        {
          "type" => "bar",
          "data" => [
            {"label" => "A", "value" => 1},
            {"label" => "", "value" => 9},
            {"label" => "B"},
            {"value" => 7}
          ]
        },
        nil
      )

      expect(result["data"]).to eq([{"label" => "A", "value" => 1.0}])
    end
  end

  describe "validation" do
    it "rejects an unknown chart type" do
      result = tool.execute(
        {"type" => "scatter", "data" => [{"label" => "A", "value" => 1}]},
        nil
      )

      expect(result["error"]).to include("type must be one of")
    end

    it "rejects empty data" do
      result = tool.execute({"type" => "bar", "data" => []}, nil)

      expect(result["error"]).to include("non-empty array")
    end

    it "rejects data with no valid points" do
      result = tool.execute(
        {"type" => "bar", "data" => [{"label" => ""}, {"value" => 1}]},
        nil
      )

      expect(result["error"]).to include("non-empty array")
    end
  end
end
