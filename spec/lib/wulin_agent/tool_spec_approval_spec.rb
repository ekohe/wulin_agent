# frozen_string_literal: true

require "rails_helper"

RSpec.describe WulinAgent::ToolSpec do
  let(:admin) { User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", admin: true) }

  before do
    WulinAgent::Catalog.reset!
    WulinAgent::ToolRegistry.reset!
    PersonScreen
    PersonGrid
  end

  describe "#execute approval gate" do
    it "runs read tools immediately under confirm_writes" do
      tool = WulinAgent::ToolRegistry.find("people__index", admin)
      result = tool.execute({"offset" => 0, "count" => 50}, nil)

      expect(result).to include("rows", "total")
      expect(result["status"]).not_to eq("approval_required")
    end

    it "returns approval_required for mutating tools under confirm_writes" do
      tool = WulinAgent::ToolRegistry.find("people__destroy", admin)
      result = tool.execute({"id" => 1}, nil)

      expect(result).to eq(
        "status" => "approval_required",
        "tool" => "people__destroy",
        "params" => {"id" => 1},
        "summary" => tool.description
      )
    end

    it "dispatches mutating tools when approved" do
      alice = Person.create!(first_name: "Alice", last_name: "Martin")
      tool = WulinAgent::ToolRegistry.find("people__destroy", admin)
      result = tool.execute({"id" => alice.id}, nil, approved: true)

      expect(result["success"]).to be(true)
      expect(Person.find_by(id: alice.id)).to be_nil
    end

    it "dispatches mutating tools in auto mode" do
      alice = Person.create!(first_name: "Alice", last_name: "Martin")
      tool = WulinAgent::ToolRegistry.find("people__destroy", admin)
      result = tool.execute({"id" => alice.id}, nil, approval_mode: :auto)

      expect(result["success"]).to be(true)
      expect(Person.find_by(id: alice.id)).to be_nil
    end
  end
end
