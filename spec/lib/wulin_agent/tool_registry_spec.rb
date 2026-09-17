# frozen_string_literal: true

require "rails_helper"
require "wulin_agent/tool_registry"

RSpec.describe WulinAgent::ToolRegistry do
  let(:admin) { User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", admin: true) }
  let(:people) { {"controller" => "people"} }

  before do
    WulinAgent::Catalog.reset!
    described_class.reset!
    PersonScreen
    PersonGrid
  end

  describe "extra_tool_builders" do
    let(:host_tool) do
      WulinAgent::ToolSpec.new(
        name: "demo_host_tool",
        controller: :host,
        operation: "demo",
        description: "Demo host tool",
        mutating: false,
        permission: nil,
        params_schema: {properties: {}, required: []},
        callable: ->(_params, _user) { {"ok" => true} }
      )
    end

    around do |example|
      WulinAgent.config.extra_tool_builders << ->(_user) { [host_tool] }
      example.run
      WulinAgent.config.extra_tool_builders.clear
    end

    it "includes host tools for an admin user" do
      names = described_class.for(admin).map(&:name)

      expect(names).to include("demo_host_tool")
    end

    it "executes a host tool" do
      tool = described_class.find("demo_host_tool", admin)

      expect(tool.execute({}, admin)).to eq("ok" => true)
    end
  end

  describe ".for" do
    it "exposes meta tools and custom actions for an admin user" do
      names = described_class.for(admin).map(&:name)

      expect(names).to include(
        "list_grids",
        "get_columns",
        "list_records",
        "read_record",
        "create_record",
        "update_record",
        "destroy_record",
        "knowledge_search",
        "knowledge_upsert",
        "knowledge_delete",
        "render_chart",
        "people__greet"
      )
    end

    it "exposes render_chart as a safe (non-mutating) tool" do
      tool = described_class.find("render_chart", admin)

      expect(tool).to be_present
      expect(tool.mutating).to be(false)
    end
  end

  describe "get_columns" do
    it "returns column metadata from the catalog" do
      tool = described_class.find("get_columns", admin)
      result = tool.execute(people, admin)

      names = result.map { |column| column[:name] }
      expect(names).to include("first_name", "last_name", "job", "status")
    end

    it "is not mutating" do
      tool = described_class.find("get_columns", admin)

      expect(tool.mutating).to be(false)
    end
  end

  describe "list_records" do
    let(:first_name_idx) { PersonGrid.columns.index { |c| c.name == :first_name } }
    let!(:alice) { Person.create!(first_name: "Alice", last_name: "Martin") }
    let!(:bob) { Person.create!(first_name: "Bob", last_name: "Smith") }

    it "lists rows via GridDispatcher" do
      tool = described_class.find("list_records", admin)
      result = tool.execute(people.merge("offset" => 0, "count" => 50), admin)

      expect(result).to include("rows", "total", "offset")
      expect(result["display"]).to eq("grid")
      expect(result["columns"]).to be_an(Array)
      expect(result["total"]).to eq(2)
      expect(result["rows"].map { |row| row[first_name_idx] }).to contain_exactly("Alice", "Bob")
      expect(result["columns"].map { |c| c["name"] }).to include("first_name", "last_name")
    end

    it "applies grid filters" do
      tool = described_class.find("list_records", admin)
      result = tool.execute(
        people.merge(
          "offset" => 0,
          "count" => 50,
          "filters" => [{"column" => "first_name", "value" => "Alice", "operator" => "equals"}]
        ),
        admin
      )

      expect(result["total"]).to eq(1)
      expect(result["rows"].map { |row| row[first_name_idx] }).to eq(["Alice"])
    end

    it "is not mutating" do
      tool = described_class.find("list_records", admin)

      expect(tool.mutating).to be(false)
    end
  end

  describe "read_record" do
    let(:first_name_idx) { PersonGrid.columns.index { |c| c.name == :first_name } }
    let!(:alice) { Person.create!(first_name: "Alice", last_name: "Martin") }

    it "returns a single record by id" do
      tool = described_class.find("read_record", admin)
      result = tool.execute(people.merge("id" => alice.id), admin)

      expect(result["display"]).to eq("grid")
      expect(result["columns"]).to be_an(Array)
      expect(result["rows"].size).to eq(1)
      expect(result["rows"].first[first_name_idx]).to eq("Alice")
    end
  end

  describe "create_record" do
    it "creates a record via GridDispatcher" do
      tool = described_class.find("create_record", admin)
      result = tool.execute(
        people.merge("attributes" => {"first_name" => "Charlie", "last_name" => "Dupont"}),
        admin,
        approved: true
      )

      expect(result["success"]).to be(true)
      expect(Person.find(result["id"]).first_name).to eq("Charlie")
    end

    it "is mutating" do
      tool = described_class.find("create_record", admin)

      expect(tool.mutating).to be(true)
    end

    it "requires attributes in the params schema" do
      tool = described_class.find("create_record", admin)

      expect(tool.params_schema[:required]).to include("attributes", "controller")
    end

    it "returns an error without attributes" do
      tool = described_class.find("create_record", admin)
      result = tool.execute(people, admin, approved: true)

      expect(result).to eq("error" => "attributes is required")
    end
  end

  describe "update_record" do
    let!(:alice) { Person.create!(first_name: "Alice", last_name: "Martin") }

    it "updates a record via GridDispatcher" do
      tool = described_class.find("update_record", admin)
      result = tool.execute(
        people.merge("id" => alice.id, "attributes" => {"first_name" => "Alicia"}),
        admin,
        approved: true
      )

      expect(result["success"]).to be(true)
      expect(alice.reload.first_name).to eq("Alicia")
    end

    it "requires id and attributes in the params schema" do
      tool = described_class.find("update_record", admin)

      expect(tool.params_schema[:required]).to contain_exactly("controller", "id", "attributes")
    end

    it "returns an error without attributes" do
      tool = described_class.find("update_record", admin)
      result = tool.execute(people.merge("id" => alice.id), admin, approved: true)

      expect(result).to eq("error" => "attributes is required")
    end
  end

  describe "destroy_record" do
    let!(:alice) { Person.create!(first_name: "Alice", last_name: "Martin") }

    it "destroys a record via GridDispatcher" do
      tool = described_class.find("destroy_record", admin)
      result = tool.execute(people.merge("id" => alice.id), admin, approved: true)

      expect(result["success"]).to be(true)
      expect(Person.find_by(id: alice.id)).to be_nil
    end
  end
end
