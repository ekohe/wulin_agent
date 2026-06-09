# frozen_string_literal: true

require "rails_helper"
require "wulin_agent/grid_dispatcher"

RSpec.describe WulinAgent::GridDispatcher do
  before { PersonGrid }

  describe ".call" do
    describe "people#index" do
      let(:first_name_idx) { PersonGrid.columns.index { |c| c.name == :first_name } }
      let!(:alice) { Person.create!(first_name: "Alice", last_name: "Martin") }
      let!(:bob) { Person.create!(first_name: "Bob", last_name: "Smith") }

      it "returns the same rows as the grid JSON" do
        result = described_class.call("people", "index", {offset: 0, count: 50}, nil)

        expect(result).to include("rows", "total", "offset")
        expect(result["total"]).to eq(2)
        expect(result["rows"].map { |row| row[first_name_idx] }).to contain_exactly("Alice", "Bob")
      end

      it "applies grid filters" do
        result = described_class.call(
          "people",
          "index",
          {
            offset: 0,
            count: 50,
            filters: [{column: "first_name", value: "Alice", operator: "equals"}]
          },
          nil
        )

        expect(result["total"]).to eq(1)
        expect(result["rows"].map { |row| row[first_name_idx] }).to eq(["Alice"])
      end
    end
  end
end
