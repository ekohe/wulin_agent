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
    def stub_chat(message_content:, stream_chunks: [], tool_flow: nil, messages: [])
      chat = instance_double("RubyLLM::Chat")
      message = instance_double("RubyLLM::Message", content: message_content)
      tool_call_handler = nil
      tool_result_handler = nil

      allow(RubyLLM).to receive(:chat).and_return(chat)
      allow(chat).to receive(:with_tools).and_return(chat)
      allow(chat).to receive(:with_instructions).and_return(chat)
      allow(chat).to receive(:on_tool_call) do |&block|
        tool_call_handler = block
        chat
      end
      allow(chat).to receive(:on_tool_result) do |&block|
        tool_result_handler = block
        chat
      end
      allow(chat).to receive(:messages).and_return(messages)
      allow(chat).to receive(:add_message)
      allow(chat).to receive(:instance_variable_set)

      allow(chat).to receive(:ask) do |_prompt, &block|
        if tool_flow
          tool_call_handler&.call(tool_flow[:tool_call])
          tool_result_handler&.call(tool_flow[:result])
        end

        stream_chunks.each do |content|
          chunk = instance_double("RubyLLM::Chunk", content: content)
          block&.call(chunk)
        end

        message
      end

      chat
    end

    it "asks the model with the user's tools attached" do
      chat = stub_chat(message_content: "There are 0 people.")

      runner = described_class.new(user: admin)
      response = runner.run("How many people?")

      expect(RubyLLM).to have_received(:chat)
      expect(chat).to have_received(:with_tools).with(*runner.tools)
      expect(chat).to have_received(:on_tool_call)
      expect(chat).to have_received(:on_tool_result)
      expect(chat).to have_received(:ask).with("How many people?")
      expect(response).to eq("There are 0 people.")
    end

    it "keeps the system prompt and only the last 10 non-system messages" do
      system_msg = instance_double("RubyLLM::Message", role: :system)
      rest_msgs = (1..12).map { |i| instance_double("RubyLLM::Message", role: :user, content: "msg #{i}") }
      all_messages = [system_msg, *rest_msgs]

      stub_chat(message_content: "ok", messages: all_messages)

      described_class.new(user: admin).run("next")

      chat = RubyLLM.chat
      expect(chat).to have_received(:instance_variable_set).with(
        :@messages,
        [system_msg, *rest_msgs.last(10)]
      )
    end

    it "yields text_delta and done events when a block is given" do
      stub_chat(message_content: "Done.", stream_chunks: ["There ", "are 2."])

      events = []
      response = described_class.new(user: admin).run("How many people?") { |event| events << event }

      expect(response).to eq("Done.")
      expect(events).to eq(
        [
          {type: :text_delta, content: "There "},
          {type: :text_delta, content: "are 2."},
          {type: :done}
        ]
      )
    end

    it "yields correlated tool_call and tool_result events" do
      tool_call = RubyLLM::ToolCall.new(
        id: "call_abc",
        name: "people__index",
        arguments: {"offset" => 0}
      )
      tool_result = {"rows" => [], "total" => 0}

      stub_chat(
        message_content: "There are 0 people.",
        stream_chunks: ["Checking..."],
        tool_flow: {tool_call: tool_call, result: tool_result}
      )

      events = []
      described_class.new(user: admin).run("How many people?") { |event| events << event }

      expect(events).to include(
        {type: :tool_call, id: "call_abc", name: "people__index", arguments: {"offset" => 0}},
        {type: :tool_result, id: "call_abc", name: "people__index", result: tool_result},
        {type: :text_delta, content: "Checking..."},
        {type: :done}
      )
    end
  end

  describe "#run_approved" do
    before { WulinAgent::Approvals.reset! }

    def stub_chat_for_approved(message_content: "Done.", stream_chunks: ["OK"])
      chat = instance_double("RubyLLM::Chat")
      message = instance_double("RubyLLM::Message", content: message_content)

      allow(RubyLLM).to receive(:chat).and_return(chat)
      allow(chat).to receive(:with_tools).and_return(chat)
      allow(chat).to receive(:with_instructions).and_return(chat)
      allow(chat).to receive(:on_tool_call).and_return(chat)
      allow(chat).to receive(:on_tool_result).and_return(chat)
      allow(chat).to receive(:messages).and_return([])
      allow(chat).to receive(:add_message)
      allow(chat).to receive(:instance_variable_set)
      allow(chat).to receive(:add_message)
      allow(chat).to receive(:complete) do |&block|
        stream_chunks.each do |content|
          chunk = instance_double("RubyLLM::Chunk", content: content)
          block&.call(chunk)
        end
        message
      end

      chat
    end

    it "executes the approved tool and streams the follow-up response" do
      alice = Person.create!(first_name: "Alice", last_name: "Martin")
      token = WulinAgent::Approvals.issue!(
        tool: "people__destroy",
        params: {"id" => alice.id},
        user_id: admin.id,
        tool_call_id: "call_1"
      )

      stub_chat_for_approved

      events = []
      runner = described_class.new(user: admin)
      response = runner.run_approved(token: token) { |event| events << event }

      expect(Person.find_by(id: alice.id)).to be_nil
      expect(response).to eq("Done.")
      expect(events).to include(
        {type: :tool_result, name: "people__destroy", result: {"success" => true}},
        {type: :text_delta, content: "OK"},
        {type: :done}
      )

      chat = RubyLLM.chat
      expect(chat).to have_received(:add_message).with(
        role: :user,
        content: "User approved people__destroy: #{ {"success" => true}.to_json }"
      )
      expect(chat).to have_received(:with_tools).with(replace: true)
      expect(chat).to have_received(:with_tools).with(*runner.tools, replace: true)
    end

    it "raises when the token is invalid" do
      stub_chat_for_approved
      runner = described_class.new(user: admin)

      expect { runner.run_approved(token: "bad") }.to raise_error(ArgumentError, "invalid approval token")
    end

    it "raises when the token has no params" do
      token = WulinAgent::Approvals.issue!(
        tool: "people__destroy",
        params: {},
        user_id: admin.id
      )

      stub_chat_for_approved
      runner = described_class.new(user: admin)

      expect { runner.run_approved(token: token) }.to raise_error(ArgumentError, "missing tool params")
    end
  end

  describe "#run_rejected" do
    before { WulinAgent::Approvals.reset! }

    def stub_chat_for_follow_up(message_content: "Understood.", stream_chunks: ["OK"])
      chat = instance_double("RubyLLM::Chat")
      message = instance_double("RubyLLM::Message", content: message_content)

      allow(RubyLLM).to receive(:chat).and_return(chat)
      allow(chat).to receive(:with_tools).and_return(chat)
      allow(chat).to receive(:with_instructions).and_return(chat)
      allow(chat).to receive(:on_tool_call).and_return(chat)
      allow(chat).to receive(:on_tool_result).and_return(chat)
      allow(chat).to receive(:messages).and_return([])
      allow(chat).to receive(:add_message)
      allow(chat).to receive(:instance_variable_set)
      allow(chat).to receive(:add_message)
      allow(chat).to receive(:complete) do |&block|
        stream_chunks.each do |content|
          chunk = instance_double("RubyLLM::Chunk", content: content)
          block&.call(chunk)
        end
        message
      end

      chat
    end

    it "invalidates the token and streams the follow-up response" do
      alice = Person.create!(first_name: "Alice", last_name: "Martin")
      token = WulinAgent::Approvals.issue!(
        tool: "people__destroy",
        params: {"id" => alice.id},
        user_id: admin.id
      )

      stub_chat_for_follow_up

      events = []
      runner = described_class.new(user: admin)
      response = runner.run_rejected(token: token) { |event| events << event }

      expect(Person.find_by(id: alice.id)).to eq(alice)
      expect(response).to eq("Understood.")
      expect(events).to eq(
        [
          {type: :text_delta, content: "OK"},
          {type: :done}
        ]
      )

      chat = RubyLLM.chat
      expect(chat).to have_received(:add_message).with(
        role: :user,
        content: "User declined people__destroy"
      )
      expect(chat).to have_received(:with_tools).with(replace: true)
      expect(WulinAgent::Approvals.consume!(token, user_id: admin.id)).to be_nil
    end

    it "uses a custom rejection reason" do
      token = WulinAgent::Approvals.issue!(
        tool: "people__destroy",
        params: {"id" => 1},
        user_id: admin.id
      )

      stub_chat_for_follow_up

      described_class.new(user: admin).run_rejected(token: token, reason: "No thanks")

      chat = RubyLLM.chat
      expect(chat).to have_received(:add_message).with(role: :user, content: "No thanks")
    end

    it "raises when the token is invalid" do
      stub_chat_for_follow_up
      runner = described_class.new(user: admin)

      expect { runner.run_rejected(token: "bad") }.to raise_error(ArgumentError, "invalid approval token")
    end
  end
end
