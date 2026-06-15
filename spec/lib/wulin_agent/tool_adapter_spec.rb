# frozen_string_literal: true

require "rails_helper"
require "ruby_llm"

RSpec.describe WulinAgent::ToolAdapter do
  let(:admin) { User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", admin: true) }

  before do
    WulinAgent::Catalog.reset!
    WulinAgent::ToolRegistry.reset!
    PersonScreen
    PersonGrid
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

      schema = tool.class.params_schema_definition.instance_variable_get(:@schema)
      expect(schema[:properties]).to include(name: {type: "string"})
    end

    it "delegates execute to ToolSpec with user and approval_mode" do
      spec = WulinAgent::ToolRegistry.find("people__greet", admin)
      tool = described_class.build([spec], user: admin, approval_mode: :auto).first

      result = tool.execute(name: "Axel")

      expect(result).to eq("success" => true, "message" => "Hello, Axel!")
    end

    it "returns approval_required for mutating tools under confirm_writes" do
      spec = WulinAgent::ToolRegistry.find("people__destroy", admin)
      tool = described_class.build([spec], user: admin, approval_mode: :confirm_writes).first

      result = tool.execute(id: 1)

      expect(result["status"]).to eq("approval_required")
    end
  end
end
