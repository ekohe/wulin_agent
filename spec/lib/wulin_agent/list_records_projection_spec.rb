# frozen_string_literal: true

require "rails_helper"
require "wulin_agent/list_records_projection"

RSpec.describe WulinAgent::ListRecordsProjection do
  before do
    WulinAgent::Catalog.reset!
    PersonGrid
  end

  def sample_row(overrides = {})
    defaults = {
      "id" => 1,
      "first_name" => "Alice",
      "last_name" => "Martin",
      "age" => 30,
      "signature" => "long signature text",
      "birthdate" => "2000-01-01",
      "job" => "Developer",
      "status" => "busy",
      "vip" => true
    }
    values = defaults.merge(overrides.stringify_keys)
    PersonGrid.columns.map { |col| values[col.name.to_s] }
  end

  let(:payload) do
    {
      "total" => 1,
      "offset" => 0,
      "rows" => [sample_row]
    }
  end

  describe "#active?" do
    it "is false without fields or omit_columns" do
      projection = described_class.new(grid: PersonGrid)

      expect(projection.active?).to be(false)
    end

    it "is true when fields are present" do
      projection = described_class.new(grid: PersonGrid, fields: ["first_name"])

      expect(projection.active?).to be(true)
    end
  end

  describe ".apply" do
    it "returns the payload unchanged when no projection is requested" do
      result = described_class.apply(grid: PersonGrid, payload: payload)

      expect(result).to eq(payload)
    end

    it "returns the payload unchanged for non-grid payloads" do
      error_payload = {"error" => "nope"}

      result = described_class.apply(
        grid: PersonGrid,
        payload: error_payload,
        fields: ["first_name"]
      )

      expect(result).to eq(error_payload)
    end

    it "projects rows to objects when fields are given" do
      result = described_class.apply(
        grid: PersonGrid,
        payload: payload,
        fields: %w[first_name job]
      )

      expect(result["rows"]).to eq([{"id" => 1, "first_name" => "Alice", "job" => "Developer"}])
      expect(result["columns"]).to eq(
        [
          {"name" => "id", "label" => "Id"},
          {"name" => "first_name", "label" => "First name"},
          {"name" => "job", "label" => "Job"}
        ]
      )
      expect(result["total"]).to eq(1)
    end

    it "projects rows to arrays when row_format is arrays" do
      result = described_class.apply(
        grid: PersonGrid,
        payload: payload,
        fields: %w[first_name last_name],
        row_format: "arrays"
      )

      expect(result["rows"]).to eq([[1, "Alice", "Martin"]])
    end

    it "drops columns with omit_columns" do
      result = described_class.apply(
        grid: PersonGrid,
        payload: payload,
        omit_columns: %w[signature]
      )

      expect(result["rows"].first).not_to have_key("signature")
      expect(result["rows"].first).to include("first_name" => "Alice")
      expect(result["columns"].map { |c| c["name"] }).not_to include("signature")
    end

    it "returns an error for unknown fields" do
      result = described_class.apply(
        grid: PersonGrid,
        payload: payload,
        fields: %w[first_name not_a_column]
      )

      expect(result["error"]).to include("Unknown column(s)", "not_a_column")
      expect(result["error"]).to include("first_name", "last_name")
    end

    it "truncates long strings when text_max_chars is set" do
      long_signature = "x" * 50
      payload = {
        "total" => 1,
        "rows" => [sample_row("signature" => long_signature)]
      }

      result = described_class.apply(
        grid: PersonGrid,
        payload: payload,
        fields: %w[signature],
        text_max_chars: 10
      )

      expect(result["rows"].first["signature"]).to eq("#{long_signature[0, 10]}…")
      expect(result["rows"].first["_truncated_columns"]).to eq(["signature"])
    end

    it "prepends id when fields are given and the grid has an id column" do
      grid = double(
        "grid",
        controller: "items",
        columns: [
          double(name: :id, label: "ID"),
          double(name: :title, label: "Title")
        ]
      )
      item_payload = {
        "total" => 1,
        "rows" => [[42, "Hello"]]
      }

      result = described_class.apply(
        grid: grid,
        payload: item_payload,
        fields: %w[title]
      )

      expect(result["rows"]).to eq([{"id" => 42, "title" => "Hello"}])
      expect(result["columns"].map { |c| c["name"] }).to eq(%w[id title])
    end
  end
end
