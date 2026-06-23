# frozen_string_literal: true

require "rails_helper"

RSpec.describe Agent::Message do
  let(:user) { User.create!(email: "msg-#{SecureRandom.hex(4)}@example.com") }
  let(:conversation) { Agent::Conversation.create!(user: user) }

  describe "validations" do
    it "rejects invalid roles" do
      message = described_class.new(conversation: conversation, role: "system", content: "x")

      expect(message).not_to be_valid
      expect(message.errors[:role]).to be_present
    end

    it "requires content" do
      message = described_class.new(conversation: conversation, role: "user", content: nil)

      expect(message).not_to be_valid
      expect(message.errors[:content]).to be_present
    end

    it "allows empty content for assistant messages with tool calls" do
      message = described_class.new(
        conversation: conversation,
        role: "assistant",
        content: "",
        metadata: {"tool_calls" => [{"id" => "call_1", "name" => "destroy_record"}]}
      )

      expect(message).to be_valid
    end
  end

  describe ".chronological" do
    it "orders messages by created_at" do
      conversation.messages.create!(role: "user", content: "first")
      conversation.messages.create!(role: "assistant", content: "second")

      expect(conversation.messages.chronological.pluck(:content)).to eq(["first", "second"])
    end
  end

  describe "metadata" do
    it "defaults to an empty hash" do
      message = conversation.messages.create!(role: "user", content: "hi")

      expect(message.metadata).to eq({})
    end

    it "stores structured tool data" do
      message = conversation.messages.create!(
        role: "assistant",
        content: "Done.",
        metadata: {"tool_calls" => [{"name" => "people__index"}]}
      )

      expect(message.reload.metadata["tool_calls"].first["name"]).to eq("people__index")
    end
  end
end
