# frozen_string_literal: true

require "rails_helper"
require "ruby_llm"

RSpec.describe WulinAgent::ToolAdapter do
  let(:admin) { User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", admin: true) }

  before do
    WulinAgent::Catalog.reset!
    WulinAgent::ToolRegistry.reset!
    load_dummy_grids
  end

  describe ".build" do
    it "wraps each ToolSpec as a RubyLLM::Tool" do
      specs = WulinAgent::ToolRegistry.for(admin)
      tools = described_class.build(specs, user: admin)

      expect(tools).not_to be_empty
      expect(tools).to all(be_a(RubyLLM::Tool))
    end

    it "preserves tool name and description" do
      spec = WulinAgent::ToolRegistry.find("people__greet", admin)
      tool = described_class.build([spec], user: admin).first

      expect(tool.name).to eq("people__greet")
      expect(tool.class.description).to eq("Say hello to someone by name")
    end

    it "exposes params_schema from the ToolSpec" do
      spec = WulinAgent::ToolRegistry.find("people__greet", admin)
      tool = described_class.build([spec], user: admin).first

      expect(tool.parameters_schema["properties"]).to include("name" => {"type" => "string"})
    end

    it "delegates execute to ToolSpec with user and approval_mode" do
      spec = WulinAgent::ToolRegistry.find("people__greet", admin)
      tool = described_class.build([spec], user: admin, approval_mode: :auto).first

      result = tool.execute(name: "Axel")

      expect(result).to eq("success" => true, "message" => "Hello, Axel!")
    end

    it "requires approval for mutating tools under confirm_writes, and only for those" do
      destroy = WulinAgent::ToolRegistry.find("destroy_record", admin)
      list = WulinAgent::ToolRegistry.find("list_records", admin)
      tools = described_class.build([destroy, list], user: admin, approval_mode: :confirm_writes)

      expect(tools.map { |tool| [tool.name, tool.requires_approval?] })
        .to eq([["destroy_record", true], ["list_records", false]])
    end

    it "pauses a valid write for approval and lets one its schema refuses run to its error" do
      spec = WulinAgent::ToolRegistry.find("create_record", admin)
      tool = described_class.build([spec], user: admin, approval_mode: :confirm_writes).first
      call = ->(attributes) {
        RubyLLM::ToolCall.new(id: "c1", name: "create_record", arguments: {"controller" => "people", "attributes" => attributes})
      }

      expect(tool.approval_resolver.call(call.call({"first_name" => "Ada"}))).to be_nil
      expect(tool.approval_resolver.call(call.call({}))).to be(true)
      expect(tool.execute(controller: "people", attributes: {})["error"]).to start_with("attributes needs at least 1 field")
    end

    it "requires no approval under auto" do
      spec = WulinAgent::ToolRegistry.find("destroy_record", admin)
      tool = described_class.build([spec], user: admin, approval_mode: :auto).first

      expect(tool.requires_approval?).to be(false)
    end
  end
end
