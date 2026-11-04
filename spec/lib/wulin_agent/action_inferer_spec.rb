# frozen_string_literal: true

require "rails_helper"

RSpec.describe WulinAgent::ActionInferer do
  let(:admin) { User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", admin: true) }

  before do
    WulinAgent::Catalog.reset!
    load_dummy_grids
  end

  describe ".build" do
    let(:grid) { WulinAgent::Catalog.find("people") }

    it "exposes greet and tag but not fullscreen" do
      names = described_class.build(grid).map(&:name)

      expect(names).to include("people__greet", "people__tag")
      expect(names).not_to include("people__fullscreen")
    end

    it "marks greet as mutating because custom actions default to POST" do
      tool = described_class.build(grid).find { |t| t.name == "people__greet" }

      expect(tool.mutating).to be(true)
      expect(tool.permission).to eq("people#greet")
    end

    it "dispatches via GridDispatcher" do
      tool = described_class.build(grid).find { |t| t.name == "people__greet" }
      result = tool.execute({"name" => "Axel"}, admin, approved: true)

      expect(result).to eq("success" => true, "message" => "Hello, Axel!")
    end

    it "uses agent_action description for greet" do
      tool = described_class.build(grid).find { |t| t.name == "people__greet" }

      expect(tool.description).to eq("Say hello to someone by name")
    end

    it "infers params schema for greet" do
      tool = described_class.build(grid).find { |t| t.name == "people__greet" }

      expect(tool.params_schema).to eq(
        properties: {name: {type: "string"}},
        required: []
      )
    end

    it "infers params schema for tag" do
      tool = described_class.build(grid).find { |t| t.name == "people__tag" }

      expect(tool.params_schema).to eq(
        properties: {person_ids: {type: "array", items: {type: "integer"}}},
        required: [:person_ids]
      )
    end

    it "dispatches tag via GridDispatcher" do
      tool = described_class.build(grid).find { |t| t.name == "people__tag" }
      result = tool.execute({"person_ids" => [1, 2]}, admin, approved: true)

      expect(result).to eq("success" => true, "count" => 2)
    end
  end
end
