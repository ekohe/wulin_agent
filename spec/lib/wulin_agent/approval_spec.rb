# frozen_string_literal: true

require "rails_helper"

RSpec.describe WulinAgent::Approvals do
  let(:read_tool) { instance_double(WulinAgent::ToolSpec, mutating: false) }
  let(:write_tool) { instance_double(WulinAgent::ToolSpec, mutating: true) }

  describe ".needs_approval?" do
    it "skips approval when already approved" do
      expect(described_class.needs_approval?(write_tool, mode: :confirm_writes, approved: true)).to be(false)
    end

    it "skips approval in auto mode" do
      expect(described_class.needs_approval?(write_tool, mode: :auto)).to be(false)
    end

    it "requires approval for all tools in confirm_all mode" do
      expect(described_class.needs_approval?(read_tool, mode: :confirm_all)).to be(true)
    end

    it "requires approval only for mutating tools in confirm_writes mode" do
      expect(described_class.needs_approval?(read_tool, mode: :confirm_writes)).to be(false)
      expect(described_class.needs_approval?(write_tool, mode: :confirm_writes)).to be(true)
    end
  end

  describe ".issue! / .consume!" do
    before { described_class.reset! }

    let(:user) { User.create!(email: "reader@example.com", admin: true) }

    it "issues a one-shot token for the user" do
      token = described_class.issue!(tool: "people__destroy", params: {"id" => 1}, user_id: user.id)

      grant = described_class.consume!(token, user_id: user.id)

      expect(grant).to include(tool: "people__destroy", params: {"id" => 1}, user_id: user.id)
    end

    it "rejects a token for another user" do
      other = User.create!(email: "other@example.com", admin: true)
      token = described_class.issue!(tool: "people__destroy", params: {}, user_id: user.id)

      expect(described_class.consume!(token, user_id: other.id)).to be_nil
    end

    it "rejects a consumed token twice" do
      token = described_class.issue!(tool: "people__destroy", params: {}, user_id: user.id)
      described_class.consume!(token, user_id: user.id)

      expect(described_class.consume!(token, user_id: user.id)).to be_nil
    end
  end

  describe ".fetch!" do
    before { described_class.reset! }

    let(:user) { User.create!(email: "fetcher@example.com", admin: true) }

    it "returns a grant without consuming it" do
      token = described_class.issue!(tool: "list_grids", params: {}, user_id: user.id)

      grant = described_class.fetch!(token, user_id: user.id)

      expect(grant).to include(tool: "list_grids", params: {}, user_id: user.id)
      expect(described_class.fetch!(token, user_id: user.id)).to include(tool: "list_grids")
    end
  end

  describe ".rejection_result" do
    it "returns a tool result that tells the agent not to retry tools" do
      result = described_class.rejection_result(tool: "destroy_record", reason: "No thanks")

      expect(result).to eq(
        "status" => "rejected",
        "tool" => "destroy_record",
        "reason" => "No thanks",
        "instruction" => "The user declined this action. Do not retry this tool or call any other tools. Reply in plain text only: briefly acknowledge what was declined."
      )
    end
  end
end
