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

    it "projects columns when fields are passed" do
      tool = described_class.find("list_records", admin)
      result = tool.execute(
        people.merge("count" => 50, "fields" => %w[first_name last_name]),
        admin
      )

      expect(result["columns"].map { |c| c["name"] }).to eq(%w[id first_name last_name])
      expect(result["rows"]).to contain_exactly(
        hash_including("first_name" => "Alice", "last_name" => "Martin"),
        hash_including("first_name" => "Bob", "last_name" => "Smith")
      )
    end

    it "omits host-configured columns by default" do
      WulinAgent.config.list_records_default_omit_columns = {"people" => %w[signature]}
      tool = described_class.find("list_records", admin)
      result = tool.execute(people.merge("count" => 50), admin)

      expect(result["columns"].map { |c| c["name"] }).not_to include("signature")
      expect(result["rows"].first).not_to have_key("signature")
    ensure
      WulinAgent.config.list_records_default_omit_columns = {}
    end

    it "returns omitted columns when named in fields" do
      WulinAgent.config.list_records_default_omit_columns = {"people" => %w[signature]}
      tool = described_class.find("list_records", admin)
      result = tool.execute(
        people.merge("count" => 50, "fields" => %w[first_name signature]),
        admin
      )

      expect(result["columns"].map { |c| c["name"] }).to include("signature")
      expect(result["rows"].first).to have_key("signature")
    ensure
      WulinAgent.config.list_records_default_omit_columns = {}
    end

    it "strips sql metadata from list responses unless debug is true" do
      tool = described_class.find("list_records", admin)
      allow(WulinAgent::GridDispatcher).to receive(:call).and_return(
        {"total" => 0, "offset" => 0, "rows" => [], "sql" => "SELECT 1"}
      )

      result = tool.execute(people.merge("count" => 50), admin)

      expect(result).not_to have_key("sql")
    end

    it "normalizes include filters for substring search before dispatch" do
      tool = described_class.find("list_records", admin)
      allow(WulinAgent::GridDispatcher).to receive(:call).and_return(
        {"total" => 0, "offset" => 0, "rows" => []}
      )

      tool.execute(
        people.merge(
          "count" => 50,
          "filters" => [{"column" => "first_name", "value" => "lic", "operator" => "include"}]
        ),
        admin
      )

      expect(WulinAgent::GridDispatcher).to have_received(:call).with(
        "people",
        "index",
        hash_including(
          "filters" => [{"column" => "first_name", "value" => "%lic%", "operator" => "include"}]
        ),
        admin
      )
    end

    it "maps starts_with to grid equals before dispatch" do
      tool = described_class.find("list_records", admin)
      allow(WulinAgent::GridDispatcher).to receive(:call).and_return(
        {"total" => 0, "offset" => 0, "rows" => []}
      )

      tool.execute(
        people.merge(
          "count" => 50,
          "filters" => [{"column" => "first_name", "value" => "Ali", "operator" => "starts_with"}]
        ),
        admin
      )

      expect(WulinAgent::GridDispatcher).to have_received(:call).with(
        "people",
        "index",
        hash_including(
          "filters" => [{"column" => "first_name", "value" => "Ali", "operator" => "equals"}]
        ),
        admin
      )
    end

    it "embeds gte filters for numeric columns before dispatch" do
      tool = described_class.find("list_records", admin)
      allow(WulinAgent::GridDispatcher).to receive(:call).and_return(
        {"total" => 0, "offset" => 0, "rows" => []}
      )

      tool.execute(
        people.merge(
          "count" => 50,
          "filters" => [{"column" => "age", "value" => "30", "operator" => "gte"}]
        ),
        admin
      )

      expect(WulinAgent::GridDispatcher).to have_received(:call).with(
        "people",
        "index",
        hash_including(
          "filters" => [{"column" => "age", "value" => ">=30", "operator" => "equals"}]
        ),
        admin
      )
    end

    it "returns an error when a filter is missing value" do
      tool = described_class.find("list_records", admin)
      allow(WulinAgent::GridDispatcher).to receive(:call)

      result = tool.execute(
        people.merge("count" => 50, "filters" => [{"column" => "first_name"}]),
        admin
      )

      expect(result["error"]).to include("requires value")
      expect(WulinAgent::GridDispatcher).not_to have_received(:call)
    end

    it "returns an error for an unknown filter column" do
      tool = described_class.find("list_records", admin)
      allow(WulinAgent::GridDispatcher).to receive(:call)

      result = tool.execute(
        people.merge(
          "count" => 50,
          "filters" => [{"column" => "not_a_column", "value" => "x", "operator" => "equals"}]
        ),
        admin
      )

      expect(result["error"]).to include("Unknown column", "not_a_column")
      expect(WulinAgent::GridDispatcher).not_to have_received(:call)
    end

    it "returns an error for date range filters on date columns" do
      tool = described_class.find("list_records", admin)
      allow(WulinAgent::GridDispatcher).to receive(:call)

      result = tool.execute(
        people.merge(
          "count" => 50,
          "filters" => [{"column" => "birthdate", "value" => "2000-01-01", "operator" => "gte"}]
        ),
        admin
      )

      expect(result["error"]).to include("not supported", "birthdate")
      expect(WulinAgent::GridDispatcher).not_to have_received(:call)
    end

    it "passes agent_fields to the grid when projecting" do
      tool = described_class.find("list_records", admin)
      allow(WulinAgent::GridDispatcher).to receive(:call).and_return(
        {"total" => 0, "offset" => 0, "rows" => []}
      )

      tool.execute(people.merge("count" => 50, "fields" => %w[first_name last_name]), admin)

      expect(WulinAgent::GridDispatcher).to have_received(:call).with(
        "people",
        "index",
        hash_including("agent_fields" => a_string_including("first_name", "last_name")),
        admin
      )
    end

    it "returns all columns when omit_columns is an empty array" do
      WulinAgent.config.list_records_default_omit_columns = {"people" => %w[signature]}
      tool = described_class.find("list_records", admin)
      first_name_idx = PersonGrid.columns.index { |c| c.name == :first_name }
      result = tool.execute(people.merge("count" => 50, "omit_columns" => []), admin)

      expect(result["rows"].first).to be_an(Array)
      expect(result["rows"].first[first_name_idx]).to eq("Alice")
    ensure
      WulinAgent.config.list_records_default_omit_columns = {}
    end

    it "is not mutating" do
      tool = described_class.find("list_records", admin)

      expect(tool.mutating).to be(false)
    end

    it "returns a structured error when SQL filtering fails" do
      tool = described_class.find("list_records", admin)
      allow(WulinAgent::GridDispatcher).to receive(:call).and_raise(
        ActiveRecord::StatementInvalid.new(
          "wrong number of bind variables (1 for 2) in: CAST(includes_chain? AS TEXT) ILIKE ?"
        )
      )

      result = tool.execute(
        people.merge(
          "filters" => [{"column" => "first_name", "value" => "Alice", "operator" => "equals"}]
        ),
        admin
      )

      expect(result).to eq(
        "error" => "Invalid filter or sort: one or more columns cannot be queried in SQL. " \
                   "Call get_columns and use only columns with filterable: true."
      )
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
