# frozen_string_literal: true

require "rails_helper"
require "wulin_agent/grid_dispatcher"

RSpec.describe WulinAgent::GridDispatcher do
  let(:admin) { User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", admin: true) }

  before { PersonGrid }

  describe ".call" do
    describe "people#index" do
      let(:first_name_idx) { PersonGrid.columns.index { |c| c.name == :first_name } }
      let!(:alice) { Person.create!(first_name: "Alice", last_name: "Martin") }
      let!(:bob) { Person.create!(first_name: "Bob", last_name: "Smith") }

      it "requires a user when wulin_permits is loaded" do
        expect {
          described_class.call("people", "index", {offset: 0, count: 50})
        }.to raise_error(ArgumentError, "user is required")
      end

      it "returns the same rows as the grid JSON" do
        result = described_class.call("people", "index", {offset: 0, count: 50}, admin)

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
          admin
        )

        expect(result["total"]).to eq(1)
        expect(result["rows"].map { |row| row[first_name_idx] }).to eq(["Alice"])
      end

      it "allows an admin user through permission checks" do
        result = described_class.call("people", "index", {offset: 0, count: 50}, admin)

        expect(result).to include("rows", "total")
      end

      it "returns unauthorized when the user lacks permission" do
        user = User.create!(email: "reader-#{SecureRandom.hex(4)}@example.com", admin: false)

        result = described_class.call("people", "index", {offset: 0, count: 50}, user)

        expect(result["error"]).to eq("unauthorized")
      end
    end
  end
end
