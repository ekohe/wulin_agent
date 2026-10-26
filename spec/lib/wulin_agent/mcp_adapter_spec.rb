# frozen_string_literal: true

require "rails_helper"
require "mcp"

RSpec.describe WulinAgent::McpAdapter do
  let(:admin) { User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", admin: true) }

  before do
    WulinAgent::Catalog.reset!
    WulinAgent::ToolRegistry.reset!
    PersonGrid
  end

  def build_tool(name)
    spec = WulinAgent::ToolRegistry.find(name, admin)
    described_class.build([spec], user: admin).first
  end

  describe ".build" do
    it "wraps each ToolSpec as an MCP::Tool subclass" do
      tools = described_class.build(WulinAgent::ToolRegistry.for(admin), user: admin)

      expect(tools).not_to be_empty
      expect(tools.all? { |tool| tool < MCP::Tool }).to be(true)
    end

    it "preserves the tool name and description" do
      tool = build_tool("list_grids")

      expect(tool.name_value).to eq("list_grids")
      expect(tool.description_value).to be_present
    end

    it "exposes the params schema for tools with arguments" do
      schema = build_tool("read_record").input_schema_value.to_h

      expect(schema[:properties]).to include(:controller, :id, :ids)
      expect(schema[:required]).to eq(["controller"])
    end

    it "marks read-only tools with read_only_hint" do
      annotations = build_tool("list_grids").annotations_value

      expect(annotations.read_only_hint).to be(true)
      expect(annotations.destructive_hint).to be(false)
    end

    it "marks mutating tools with destructive_hint" do
      annotations = build_tool("destroy_record").annotations_value

      expect(annotations.read_only_hint).to be(false)
      expect(annotations.destructive_hint).to be(true)
    end
  end

  describe "execution" do
    it "runs the ToolSpec and wraps the result as a JSON text response" do
      response = build_tool("list_grids").call(server_context: nil)

      expect(response).to be_a(MCP::Tool::Response)
      expect(response).not_to be_error

      text = response.content.first[:text]
      expect { JSON.parse(text) }.not_to raise_error
    end

    it "passes stringified arguments through to the ToolSpec" do
      spec = WulinAgent::ToolRegistry.find("get_columns", admin)
      received = nil
      allow(spec).to receive(:execute) { |params, *|
        received = params
        []
      }

      described_class.build([spec], user: admin).first.call(controller: "people", server_context: nil)

      expect(received).to eq("controller" => "people")
    end
  end
end
