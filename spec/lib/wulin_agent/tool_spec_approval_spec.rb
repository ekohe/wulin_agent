# frozen_string_literal: true

require "rails_helper"

RSpec.describe WulinAgent::ToolSpec do
  let(:admin) { User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", admin: true) }
  let(:people) { {"controller" => "people"} }

  before do
    WulinAgent::Catalog.reset!
    WulinAgent::ToolRegistry.reset!
    load_dummy_grids
  end

  describe "#execute approval gate" do
    it "runs read tools immediately under confirm_writes" do
      tool = WulinAgent::ToolRegistry.find("list_records", admin)
      result = tool.execute(people.merge("offset" => 0, "count" => 50), admin)

      expect(result).to include("rows", "total")
      expect(result["status"]).not_to eq("approval_required")
    end

    it "returns approval_required for mutating tools under confirm_writes" do
      tool = WulinAgent::ToolRegistry.find("destroy_record", admin)
      result = tool.execute(people.merge("id" => 1), nil)

      expect(result).to eq(
        "status" => "approval_required",
        "tool" => "destroy_record",
        "params" => people.merge("id" => 1),
        "summary" => tool.description
      )
    end

    it "answers a write its schema refuses instead of asking for its approval" do
      tool = WulinAgent::ToolRegistry.find("create_record", admin)
      result = tool.execute(people.merge("attributes" => {}), admin)

      expect(result["status"]).not_to eq("approval_required")
      expect(result["error"]).to start_with("attributes needs at least 1 field")
    end

    it "answers an update with no fields instead of asking for its approval" do
      tool = WulinAgent::ToolRegistry.find("update_record", admin)
      result = tool.execute(people.merge("id" => 1, "attributes" => {}), admin)

      expect(result["status"]).not_to eq("approval_required")
      expect(result["error"]).to start_with("attributes needs at least 1 field")
    end

    it "answers an empty create in auto mode without writing" do
      tool = WulinAgent::ToolRegistry.find("create_record", admin)
      result = nil

      expect {
        result = tool.execute(people.merge("attributes" => {}), admin, approval_mode: :auto)
      }.not_to change(Person, :count)
      expect(result["error"]).to start_with("attributes needs at least 1 field")
    end

    it "answers an empty create that was already approved without writing" do
      tool = WulinAgent::ToolRegistry.find("create_record", admin)
      result = nil

      expect {
        result = tool.execute(people.merge("attributes" => {}), admin, approved: true)
      }.not_to change(Person, :count)
      expect(result["error"]).to start_with("attributes needs at least 1 field")
    end

    it "still asks for the approval of a write its schema accepts" do
      tool = WulinAgent::ToolRegistry.find("create_record", admin)
      result = tool.execute(people.merge("attributes" => {"first_name" => "Ada"}), admin)

      expect(result["status"]).to eq("approval_required")
    end

    it "names a required field that is missing" do
      tool = WulinAgent::ToolRegistry.find("destroy_record", admin)

      expect(tool.execute({"id" => 1}, admin)).to eq("error" => "controller is required")
    end

    it "dispatches mutating tools when approved" do
      alice = Person.create!(first_name: "Alice", last_name: "Martin")
      tool = WulinAgent::ToolRegistry.find("destroy_record", admin)
      result = tool.execute(people.merge("id" => alice.id), admin, approved: true)

      expect(result["success"]).to be(true)
      expect(Person.find_by(id: alice.id)).to be_nil
    end

    it "dispatches mutating tools in auto mode" do
      alice = Person.create!(first_name: "Alice", last_name: "Martin")
      tool = WulinAgent::ToolRegistry.find("destroy_record", admin)
      result = tool.execute(people.merge("id" => alice.id), admin, approval_mode: :auto)

      expect(result["success"]).to be(true)
      expect(Person.find_by(id: alice.id)).to be_nil
    end

    it "returns an error when destroy is approved without id" do
      tool = WulinAgent::ToolRegistry.find("destroy_record", admin)
      result = tool.execute(people, admin, approved: true)

      expect(result).to eq("error" => "id is required")
    end
  end
end
