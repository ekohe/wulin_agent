# frozen_string_literal: true

require "rails_helper"

RSpec.describe Agent::Conversation do
  let(:user) { User.create!(email: "conv-#{SecureRandom.hex(4)}@example.com") }

  describe "validations" do
    it "requires a valid approval_mode" do
      conversation = described_class.new(user: user, approval_mode: "invalid")

      expect(conversation).not_to be_valid
      expect(conversation.errors[:approval_mode]).to be_present
    end

    it "accepts all approval modes" do
      described_class::APPROVAL_MODES.each do |mode|
        conversation = described_class.new(user: user, approval_mode: mode)
        expect(conversation).to be_valid
      end
    end
  end

  describe "defaults" do
    it "defaults approval_mode to confirm_writes" do
      conversation = described_class.create!(user: user)

      expect(conversation.approval_mode).to eq("confirm_writes")
    end
  end

  describe "associations" do
    it "destroys messages when destroyed" do
      conversation = described_class.create!(user: user)
      conversation.messages.create!(role: "user", content: "hi")

      expect { conversation.destroy }.to change(Agent::Message, :count).by(-1)
    end
  end

  describe "#approval_mode_sym" do
    it "returns the approval mode as a symbol" do
      conversation = described_class.create!(user: user, approval_mode: "auto")

      expect(conversation.approval_mode_sym).to eq(:auto)
    end
  end

  describe "#history_for_runner" do
    it "returns chronological messages for the runner" do
      conversation = described_class.create!(user: user)
      conversation.messages.create!(role: "user", content: "first")
      conversation.messages.create!(role: "assistant", content: "second")

      expect(conversation.history_for_runner).to eq(
        [
          {role: :user, content: "first"},
          {role: :assistant, content: "second"}
        ]
      )
    end

    it "can exclude the last message" do
      conversation = described_class.create!(user: user)
      conversation.messages.create!(role: "user", content: "first")
      conversation.messages.create!(role: "assistant", content: "second")

      expect(conversation.history_for_runner(exclude_last: true)).to eq(
        [{role: :user, content: "first"}]
      )
    end
  end
end
