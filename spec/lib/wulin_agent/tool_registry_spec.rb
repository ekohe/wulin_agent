# frozen_string_literal: true

require "rails_helper"
require "wulin_agent/tool_registry"

RSpec.describe WulinAgent::ToolRegistry do
  let(:admin) { User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", admin: true) }

  before do
    WulinAgent::Catalog.reset!
    described_class.reset!
    PersonScreen
    PersonGrid
  end

  describe ".for" do
    it "exposes standard people tools for an admin user" do
      names = described_class.for(admin).map(&:name)

      expect(names).to include(
        "people__get_columns",
        "people__index",
        "people__read",
        "people__create",
        "people__update",
        "people__destroy",
        "people__greet"
      )
    end
  end

  describe "people__get_columns" do
    it "returns column metadata from the catalog" do
      tool = described_class.find("people__get_columns", admin)
      result = tool.execute({}, nil)

      names = result.map { |column| column[:name] }
      expect(names).to include("first_name", "last_name", "job", "status")
    end

    it "is not mutating" do
      tool = described_class.find("people__get_columns", admin)

      expect(tool.mutating).to be(false)
    end
  end

  describe "people__index" do
    let(:first_name_idx) { PersonGrid.columns.index { |c| c.name == :first_name } }
    let!(:alice) { Person.create!(first_name: "Alice", last_name: "Martin") }
    let!(:bob) { Person.create!(first_name: "Bob", last_name: "Smith") }

    it "lists rows via GridDispatcher" do
      tool = described_class.find("people__index", admin)
      result = tool.execute({"offset" => 0, "count" => 50}, nil)

      expect(result).to include("rows", "total", "offset")
      expect(result["total"]).to eq(2)
      expect(result["rows"].map { |row| row[first_name_idx] }).to contain_exactly("Alice", "Bob")
    end

    it "applies grid filters" do
      tool = described_class.find("people__index", admin)
      result = tool.execute(
        {
          "offset" => 0,
          "count" => 50,
          "filters" => [{"column" => "first_name", "value" => "Alice", "operator" => "equals"}]
        },
        nil
      )

      expect(result["total"]).to eq(1)
      expect(result["rows"].map { |row| row[first_name_idx] }).to eq(["Alice"])
    end

    it "is not mutating" do
      tool = described_class.find("people__index", admin)

      expect(tool.mutating).to be(false)
    end
  end

  describe "people__read" do
    let(:first_name_idx) { PersonGrid.columns.index { |c| c.name == :first_name } }
    let!(:alice) { Person.create!(first_name: "Alice", last_name: "Martin") }

    it "returns a single record by id" do
      tool = described_class.find("people__read", admin)
      result = tool.execute({"id" => alice.id}, nil)

      expect(result["rows"].size).to eq(1)
      expect(result["rows"].first[first_name_idx]).to eq("Alice")
    end
  end

  describe "people__create" do
    it "creates a record via GridDispatcher" do
      tool = described_class.find("people__create", admin)
      result = tool.execute(
        {"attributes" => {"first_name" => "Charlie", "last_name" => "Dupont"}},
        nil
      )

      expect(result["success"]).to be(true)
      expect(Person.find(result["id"]).first_name).to eq("Charlie")
    end

    it "is mutating" do
      tool = described_class.find("people__create", admin)

      expect(tool.mutating).to be(true)
    end
  end

  describe "people__update" do
    let!(:alice) { Person.create!(first_name: "Alice", last_name: "Martin") }

    it "updates a record via GridDispatcher" do
      tool = described_class.find("people__update", admin)
      result = tool.execute(
        {
          "id" => alice.id,
          "attributes" => {"first_name" => "Alicia"}
        },
        nil
      )

      expect(result["success"]).to be(true)
      expect(alice.reload.first_name).to eq("Alicia")
    end
  end

  describe "people__destroy" do
    let!(:alice) { Person.create!(first_name: "Alice", last_name: "Martin") }

    it "destroys a record via GridDispatcher" do
      tool = described_class.find("people__destroy", admin)
      result = tool.execute({"id" => alice.id}, nil)

      expect(result["success"]).to be(true)
      expect(Person.find_by(id: alice.id)).to be_nil
    end
  end
end
