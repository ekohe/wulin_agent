# frozen_string_literal: true

require "rails_helper"
require "ruby_llm"

RSpec.describe WulinAgent::Runner do
  let(:admin) { User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", admin: true) }

  before do
    WulinAgent::Catalog.reset!
    WulinAgent::ToolRegistry.reset!
    PersonScreen
    PersonGrid
  end

  describe "#tools" do
    it "returns RubyLLM tools scoped to the user" do
      runner = described_class.new(user: admin)
      names = runner.tools.map(&:name)

      expect(names).to include("people__index", "people__greet")
    end

    it "respects approval_mode when building tools" do
      runner = described_class.new(user: admin, approval_mode: :confirm_writes)
      destroy = runner.tools.find { |t| t.name == "people__destroy" }

      result = destroy.execute(id: 999)

      expect(result["status"]).to eq("approval_required")
    end
  end

  describe "#run" do
    it "asks the model with the user's tools attached" do
      chat = instance_double("RubyLLM::Chat")
      message = instance_double("RubyLLM::Message", content: "There are 0 people.")

      allow(RubyLLM).to receive(:chat).and_return(chat)
      allow(chat).to receive(:with_tools).and_return(chat)
      allow(chat).to receive(:with_instructions).and_return(chat)
      allow(chat).to receive(:messages).and_return([])
      allow(chat).to receive(:instance_variable_set)
      allow(chat).to receive(:ask).with("How many people?").and_return(message)

      runner = described_class.new(user: admin)
      response = runner.run("How many people?")

      expect(RubyLLM).to have_received(:chat)
      expect(chat).to have_received(:with_tools).with(*runner.tools)
      expect(chat).to have_received(:ask).with("How many people?")
      expect(response).to eq("There are 0 people.")
    end

    it "keeps the system prompt and only the last 10 non-system messages" do
      chat = instance_double("RubyLLM::Chat")
      message = instance_double("RubyLLM::Message", content: "ok")
      system_msg = instance_double("RubyLLM::Message", role: :system)
      rest_msgs = (1..12).map { |i| instance_double("RubyLLM::Message", role: :user, content: "msg #{i}") }
      all_messages = [system_msg, *rest_msgs]

      allow(RubyLLM).to receive(:chat).and_return(chat)
      allow(chat).to receive(:with_tools).and_return(chat)
      allow(chat).to receive(:with_instructions).and_return(chat)
      allow(chat).to receive(:messages).and_return(all_messages)
      allow(chat).to receive(:instance_variable_set).with(:@messages, anything)
      allow(chat).to receive(:ask).and_return(message)

      described_class.new(user: admin).run("next")

      expect(chat).to have_received(:instance_variable_set).with(
        :@messages,
        [system_msg, *rest_msgs.last(10)]
      )
    end
  end
end
