# frozen_string_literal: true

require "rails_helper"
require "wulin_agent/grid_result"

RSpec.describe WulinAgent::GridResult do
  before do
    WulinAgent::Catalog.reset!
    PersonGrid
  end

  describe ".grid_result?" do
    it "is true for Wulin index JSON" do
      expect(described_class.grid_result?("rows" => [], "total" => 0)).to be(true)
    end

    it "is false for errors and non-grid payloads" do
      expect(described_class.grid_result?("error" => "unauthorized")).to be(false)
      expect(described_class.grid_result?(nil)).to be(false)
      expect(described_class.grid_result?([])).to be(false)
    end
  end

  describe ".wrap" do
    it "adds display and columns for grid payloads" do
      payload = {"total" => 1, "offset" => 0, "rows" => [["Alice", "Martin"]]}

      result = described_class.wrap(PersonGrid, payload)

      expect(result["display"]).to eq("grid")
      expect(result["total"]).to eq(1)
      expect(result["columns"]).to include(
        hash_including("name" => "first_name", "label" => "First name"),
        hash_including("name" => "last_name")
      )
    end

    it "returns the payload unchanged when it is not a grid result" do
      payload = {"error" => "unauthorized"}

      expect(described_class.wrap(PersonGrid, payload)).to eq(payload)
    end

    it "aligns column headers with the grid column order" do
      payload = {"total" => 0, "rows" => []}

      result = described_class.wrap(PersonGrid, payload)
      names = result["columns"].map { |c| c["name"] }

      expect(names).to eq(PersonGrid.columns.map { |c| c.name.to_s })
    end
  end
end
