# frozen_string_literal: true

require "rails_helper"

RSpec.describe WulinAgent::SkillTools do
  let(:admin) { User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", admin: true) }

  def find_tool(name)
    described_class.build.find { |tool| tool.name == name }
  end

  describe "skill_list" do
    let(:tool) { find_tool("skill_list") }

    before do
      WulinAgent::Skill.create!(name: "zebra", description: "last", instructions: "i")
      WulinAgent::Skill.create!(name: "alpha", description: "first", instructions: "i")
    end

    it "is not mutating" do
      expect(tool.mutating).to be(false)
    end

    it "returns skills ordered by name without instructions" do
      result = tool.execute({}, admin)

      expect(result.map { |skill| skill["name"] }).to eq(%w[alpha zebra])
      expect(result.first).to eq("name" => "alpha", "description" => "first", "usage_count" => 0)
    end
  end

  describe "skill_read" do
    let(:tool) { find_tool("skill_read") }

    before do
      WulinAgent::Skill.create!(name: "attach_seats", description: "d", instructions: "1. do this")
    end

    it "is not mutating" do
      expect(tool.mutating).to be(false)
    end

    it "returns the full instructions and increments usage_count" do
      result = tool.execute({"name" => "attach_seats"}, admin)

      expect(result).to eq(
        "name" => "attach_seats",
        "description" => "d",
        "instructions" => "1. do this",
        "usage_count" => 1,
        "tool_sequence" => []
      )
    end

    it "matches the name case-insensitively" do
      result = tool.execute({"name" => "ATTACH_SEATS"}, admin)

      expect(result["name"]).to eq("attach_seats")
    end

    it "sanitizes legacy tool_sequence payloads before returning them" do
      WulinAgent::Skill.create!(
        name: "legacy_plan",
        description: "d",
        instructions: "i",
        tool_sequence: [
          {
            "tool" => "provision_prompt_config",
            "params" => {"plan" => {"theme_id" => 39, "prompts" => [{"prompt" => "x" * 200}]}, "dry_run" => true}
          }
        ]
      )

      result = tool.execute({"name" => "legacy_plan"}, admin)

      expect(result["tool_sequence"]).to eq(
        [{"tool" => "provision_prompt_config", "params" => {"dry_run" => true}}]
      )
    end

    it "returns an error when the skill is missing" do
      result = tool.execute({"name" => "missing"}, admin)

      expect(result).to eq("error" => "skill not found")
    end

    it "returns an error when name is blank" do
      result = tool.execute({}, admin)

      expect(result).to eq("error" => "name is required")
    end
  end

  describe "skill_create" do
    let(:tool) { find_tool("skill_create") }

    it "is mutating" do
      expect(tool.mutating).to be(true)
    end

    it "creates a new skill when approved" do
      result = tool.execute(
        {"name" => "new_skill", "description" => "d", "instructions" => "i"},
        admin,
        approved: true
      )

      expect(result).to eq(
        "name" => "new_skill",
        "description" => "d",
        "instructions" => "i",
        "usage_count" => 0,
        "tool_sequence" => []
      )
      expect(WulinAgent::Skill.find_by(name: "new_skill")).to be_present
    end

    it "requires approval under confirm_writes" do
      result = tool.execute(
        {"name" => "new_skill", "description" => "d", "instructions" => "i"},
        admin
      )

      expect(result["status"]).to eq("approval_required")
      expect(result["tool"]).to eq("skill_create")
      expect(WulinAgent::Skill.find_by(name: "new_skill")).to be_nil
    end

    it "persists tool_sequence and created_by" do
      sequence = [{"tool" => "list_records", "params" => {"controller" => "people"}}]

      result = tool.execute(
        {"name" => "seq_skill", "description" => "d", "instructions" => "i", "tool_sequence" => sequence},
        admin,
        approved: true
      )

      expect(result["tool_sequence"]).to eq(sequence)
      skill = WulinAgent::Skill.find_by(name: "seq_skill")
      expect(skill.tool_sequence).to eq(sequence)
      expect(skill.created_by).to eq(admin.id)
    end

    it "returns an error for a duplicate name" do
      WulinAgent::Skill.create!(name: "dup", description: "d", instructions: "i")

      result = tool.execute(
        {"name" => "dup", "description" => "d2", "instructions" => "i2"},
        admin,
        approved: true
      )

      expect(result["error"]).to be_present
    end
  end

  describe "skill_update" do
    let(:tool) { find_tool("skill_update") }

    before do
      WulinAgent::Skill.create!(name: "edit_me", description: "old", instructions: "old")
    end

    it "is mutating" do
      expect(tool.mutating).to be(true)
    end

    it "updates an existing skill when approved" do
      result = tool.execute(
        {"name" => "edit_me", "description" => "new", "instructions" => "new"},
        admin,
        approved: true
      )

      expect(result["description"]).to eq("new")
      expect(result["instructions"]).to eq("new")
    end

    it "returns an error when the skill is missing" do
      result = tool.execute({"name" => "missing"}, admin, approved: true)

      expect(result).to eq("error" => "skill not found")
    end

    it "requires approval under confirm_writes" do
      result = tool.execute({"name" => "edit_me", "description" => "new"}, admin)

      expect(result["status"]).to eq("approval_required")
    end
  end
end
