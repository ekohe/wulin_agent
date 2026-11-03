# frozen_string_literal: true

require "rails_helper"

RSpec.describe WulinAgent::Approvals do
  include ActiveSupport::Testing::TimeHelpers

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

  describe ".issue! / .claim!" do
    before { described_class.reset! }

    let(:user) { User.create!(email: "reader@example.com", admin: true) }

    it "issues a one-shot token for the user, with its expiry" do
      issued = described_class.issue!(tool: "people__destroy", params: {"id" => 1}, user_id: user.id)

      expect(issued.expires_at).to be_within(1.second).of(described_class::TTL.from_now)
      claim = described_class.claim!(issued.token, user_id: user.id)
      expect(claim.outcome).to eq(:granted)
      expect(claim.grant).to include(tool: "people__destroy", params: {"id" => 1}, user_id: user.id)
    end

    it "refuses a token for another user" do
      other = User.create!(email: "other@example.com", admin: true)
      token = described_class.issue!(tool: "people__destroy", params: {}, user_id: user.id).token

      expect { described_class.claim!(token, user_id: other.id) }.to raise_error(described_class::UnknownToken)
      expect(described_class.claim!(token, user_id: user.id).grant).to include(tool: "people__destroy")
    end

    it "refuses a token answered once already" do
      token = described_class.issue!(tool: "people__destroy", params: {}, user_id: user.id).token
      described_class.claim!(token, user_id: user.id)

      expect { described_class.claim!(token, user_id: user.id) }.to raise_error(described_class::UnknownToken)
    end

    it "preserves a grant when the issuing process loses its memory" do
      token = described_class.issue!(tool: "people__destroy", params: {"id" => 1}, user_id: user.id, tool_call_id: "call-1").token
      described_class.reset!

      expect(described_class.claim!(token, user_id: user.id).grant).to include(
        tool: "people__destroy", params: {"id" => 1}, user_id: user.id, tool_call_id: "call-1"
      )
    end

    it "persists only the token digest and hides private parameters from inspection" do
      token = described_class.issue!(tool: "people__destroy", params: {"content" => "Private test note"}, user_id: user.id).token
      record = WulinAgent::ApprovalGrant.find_by!(token_digest: Digest::SHA256.hexdigest(token))

      expect(record.inspect).not_to include(token, "Private test note")
      expect(described_class.fetch!(token, user_id: user.id)).to include(params: {"content" => "Private test note"})
    end

    it "spends an expired grant as expired, once" do
      token = described_class.issue!(tool: "people__destroy", params: {}, user_id: user.id, tool_call_id: "call-1").token

      travel described_class::TTL + 1.second do
        expect(described_class.fetch!(token, user_id: user.id)).to be_nil
        expect(described_class.pending_expiry(token, user_id: user.id)).to be_nil

        claim = described_class.claim!(token, user_id: user.id)
        expect(claim).to be_expired
        expect(claim.grant).to include(tool: "people__destroy", tool_call_id: "call-1")
        expect { described_class.claim!(token, user_id: user.id) }.to raise_error(described_class::UnknownToken)
      end
    end

    it "keeps an expired grant through the retention window, then drops it on the next issue" do
      token = described_class.issue!(tool: "people__destroy", params: {}, user_id: user.id).token

      travel described_class::TTL + 1.minute do
        described_class.issue!(tool: "list_grids", params: {}, user_id: user.id)
        expect(WulinAgent::ApprovalGrant.where(token_digest: Digest::SHA256.hexdigest(token))).to exist
      end

      travel described_class::TTL + described_class::RETENTION + 1.minute do
        described_class.issue!(tool: "list_grids", params: {}, user_id: user.id)
        expect(WulinAgent::ApprovalGrant.where(token_digest: Digest::SHA256.hexdigest(token))).not_to exist
      end
    end
  end

  describe ".pending_expiry" do
    let(:user) { User.create!(email: "pending@example.com", admin: true) }

    it "gives the deadline until the grant is answered" do
      issued = described_class.issue!(tool: "people__destroy", params: {}, user_id: user.id)

      expect(described_class.pending_expiry(issued.token, user_id: user.id)).to be_within(1.second).of(issued.expires_at)
      described_class.claim!(issued.token, user_id: user.id)
      expect(described_class.pending_expiry(issued.token, user_id: user.id)).to be_nil
    end
  end

  describe ".fetch!" do
    before { described_class.reset! }

    let(:user) { User.create!(email: "fetcher@example.com", admin: true) }

    it "returns a grant without consuming it" do
      token = described_class.issue!(tool: "list_grids", params: {}, user_id: user.id).token

      grant = described_class.fetch!(token, user_id: user.id)

      expect(grant).to include(tool: "list_grids", params: {}, user_id: user.id)
      expect(described_class.fetch!(token, user_id: user.id)).to include(tool: "list_grids")
    end
  end

  describe ".expiry_result" do
    it "tells the agent the tool did not run and not to retry it" do
      result = described_class.expiry_result(tool: "destroy_record")

      expect(result).to include("status" => "expired", "tool" => "destroy_record")
      expect(result["instruction"]).to include("did not run", "Do not retry")
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
