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

      expect(names).to include("list_records", "people__greet", "knowledge_search")
    end

    it "mentions knowledge_search in the system prompt" do
      runner = described_class.new(user: admin)

      expect(runner.send(:system_prompt)).to include("knowledge_search")
    end

    it "injects global acronyms into the system prompt" do
      WulinAgent::Knowledge.create!(key: "NHK", value: "Customer NHK", category: "acronym")
      WulinAgent::Knowledge.create!(key: "X", value: "scoped", category: "acronym", scope: "orders")

      prompt = described_class.new(user: admin).send(:system_prompt)

      expect(prompt).to include("Domain acronyms:")
      expect(prompt).to include("NHK: Customer NHK")
      expect(prompt).not_to include("X: scoped")
    end

    it "omits the acronyms section when none are configured" do
      prompt = described_class.new(user: admin).send(:system_prompt)

      expect(prompt).not_to include("Domain acronyms:")
    end

    it "respects approval_mode when building tools" do
      runner = described_class.new(user: admin, approval_mode: :confirm_writes)
      destroy = runner.tools.find { |t| t.name == "destroy_record" }

      result = destroy.execute(controller: "people", id: 999)

      expect(result).to be_a(RubyLLM::Tool::Halt)
      expect(result.content["status"]).to eq("approval_required")
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
        halt_result = nil
        if tool_flow
          tool_call_handler&.call(tool_flow[:tool_call])
          tool_result_handler&.call(tool_flow[:result])
          halt_result = tool_flow[:result] if tool_flow[:result].is_a?(RubyLLM::Tool::Halt)
        end

        unless halt_result
          stream_chunks.each do |content|
            chunk = instance_double("RubyLLM::Chunk", content: content)
            block&.call(chunk)
          end
        end

        halt_result || message
      end

      chat
    end

    it "asks the model with the user's tools attached" do
      chat = stub_chat(message_content: "There are 0 people.")

      runner = described_class.new(user: admin)
      response = runner.run("How many people?")

      expect(RubyLLM).to have_received(:chat).with(model: RubyLLM.config.default_model)
      expect(chat).to have_received(:with_tools).with(*runner.tools)
      expect(chat).to have_received(:on_tool_call)
      expect(chat).to have_received(:on_tool_result)
      expect(chat).to have_received(:ask).with("How many people?")
      expect(response).to eq("There are 0 people.")
    end

    it "uses an explicit model when passed" do
      chat = stub_chat(message_content: "ok")

      described_class.new(user: admin, model: "claude-sonnet-4-6").run("hi")

      expect(RubyLLM).to have_received(:chat).with(model: "claude-sonnet-4-6")
    end

    it "keeps the system prompt and only the last 10 non-system messages" do
      system_msg = instance_double("RubyLLM::Message", role: :system)
      rest_msgs = (1..12).map do |i|
        instance_double("RubyLLM::Message", role: :user, content: "msg #{i}", tool_result?: false)
      end
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
        name: "list_records",
        arguments: {"controller" => "people", "offset" => 0}
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
        {type: :tool_call, id: "call_abc", name: "list_records", arguments: {"controller" => "people", "offset" => 0}},
        {type: :tool_result, id: "call_abc", name: "list_records", result: tool_result},
        {type: :text_delta, content: "Checking..."},
        {type: :done}
      )
    end

    it "halts without text after approval_required" do
      WulinAgent::Approvals.reset!
      tool_call = RubyLLM::ToolCall.new(
        id: "call_create",
        name: "create_record",
        arguments: {"controller" => "people", "attributes" => {"first_name" => "AMOGUS"}}
      )
      approval_result = RubyLLM::Tool::Halt.new(
        "status" => "approval_required",
        "tool" => "create_record",
        "params" => {"controller" => "people", "attributes" => {"first_name" => "AMOGUS"}},
        "summary" => "Create person"
      )

      stub_chat(
        message_content: "",
        stream_chunks: ["Should not appear"],
        tool_flow: {tool_call: tool_call, result: approval_result}
      )

      events = []
      response = described_class.new(user: admin).run("create AMOGUS") { |event| events << event }

      expect(response).to eq("")
      expect(events).to include(hash_including(type: :tool_result, name: "create_record"))
      expect(events).not_to include(hash_including(type: :text_delta))
      expect(events.last).to eq(type: :done)
    end
  end

  describe "#run_approved" do
    before { WulinAgent::Approvals.reset! }

    def stub_chat_for_approved(message_content: "Done.", stream_chunks: ["OK"], tool_flow: nil)
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
      allow(chat).to receive(:messages).and_return([])
      allow(chat).to receive(:add_message)
      allow(chat).to receive(:instance_variable_set)
      allow(chat).to receive(:complete) do |&block|
        halt_result = nil
        if tool_flow
          tool_call_handler&.call(tool_flow[:tool_call])
          tool_result_handler&.call(tool_flow[:result])
          halt_result = tool_flow[:result] if tool_flow[:result].is_a?(RubyLLM::Tool::Halt)
        end

        unless halt_result
          stream_chunks.each do |content|
            chunk = instance_double("RubyLLM::Chunk", content: content)
            block&.call(chunk)
          end
        end

        halt_result || message
      end

      chat
    end

    it "executes the approved tool and streams the follow-up response" do
      alice = Person.create!(first_name: "Alice", last_name: "Martin")
      token = WulinAgent::Approvals.issue!(
        tool: "destroy_record",
        params: {"controller" => "people", "id" => alice.id},
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
        {type: :tool_result, id: "call_1", name: "destroy_record", result: {"success" => true}},
        {type: :text_delta, content: "OK"},
        {type: :done}
      )

      chat = RubyLLM.chat
      expect(chat).to have_received(:complete)
      expect(chat).not_to have_received(:add_message).with(
        role: :user,
        content: a_string_including("User approved")
      )
    end

    it "raises when the token is invalid" do
      stub_chat_for_approved
      runner = described_class.new(user: admin)

      expect { runner.run_approved(token: "bad") }.to raise_error(ArgumentError, "invalid approval token")
    end

    it "executes tools that require no params" do
      token = WulinAgent::Approvals.issue!(
        tool: "list_grids",
        params: {},
        user_id: admin.id
      )

      stub_chat_for_approved
      runner = described_class.new(user: admin)

      events = []
      response = runner.run_approved(token: token) { |event| events << event }

      expect(response).to eq("Done.")
      expect(events).to include(
        hash_including(type: :tool_result, name: "list_grids")
      )
    end

    it "continues the agent turn with tools after approval" do
      WulinAgent::Approvals.reset!
      alice = Person.create!(first_name: "Alice", last_name: "Martin")
      token = WulinAgent::Approvals.issue!(
        tool: "list_records",
        params: {"controller" => "people"},
        user_id: admin.id,
        tool_call_id: "call_list"
      )
      history = [
        {
          role: :user,
          content: "Delete Alice"
        },
        {
          role: :assistant,
          content: "",
          metadata: {
            "tool_calls" => [
              {"id" => "call_list", "name" => "list_records", "arguments" => {"controller" => "people"}},
              {"id" => "call_destroy", "name" => "destroy_record", "arguments" => {"controller" => "people", "id" => alice.id}}
            ],
            "tool_results" => [
              {
                "id" => "call_list",
                "name" => "list_records",
                "result" => {"status" => "approval_required", "approval_token" => token}
              }
            ]
          }
        }
      ]
      destroy_call = RubyLLM::ToolCall.new(
        id: "call_destroy",
        name: "destroy_record",
        arguments: {"controller" => "people", "id" => alice.id}
      )
      approval_result = RubyLLM::Tool::Halt.new(
        "status" => "approval_required",
        "tool" => "destroy_record",
        "params" => {"controller" => "people", "id" => alice.id},
        "summary" => "Delete person"
      )

      stub_chat_for_approved(
        message_content: "",
        stream_chunks: [],
        tool_flow: {tool_call: destroy_call, result: approval_result}
      )

      events = []
      runner = described_class.new(user: admin, history: history)
      response = runner.run_approved(token: token) { |event| events << event }

      expect(response).to eq("")
      expect(events).to include(
        hash_including(type: :tool_result, id: "call_list", name: "list_records"),
        hash_including(type: :tool_call, id: "call_destroy", name: "destroy_record"),
        hash_including(type: :tool_result, id: "call_destroy", name: "destroy_record")
      )
      expect(events).not_to include(hash_including(type: :text_delta))
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
        tool: "destroy_record",
        params: {"controller" => "people", "id" => alice.id},
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
      expect(chat).to have_received(:complete)
      expect(chat).not_to have_received(:add_message).with(
        role: :user,
        content: "User declined destroy_record"
      )
      expect(WulinAgent::Approvals.consume!(token, user_id: admin.id)).to be_nil
    end

    it "uses a custom rejection reason" do
      token = WulinAgent::Approvals.issue!(
        tool: "destroy_record",
        params: {"controller" => "people", "id" => 1},
        user_id: admin.id
      )

      stub_chat_for_follow_up

      described_class.new(user: admin).run_rejected(token: token, reason: "No thanks")

      chat = RubyLLM.chat
      expect(chat).to have_received(:complete)
      expect(chat).not_to have_received(:add_message).with(role: :user, content: "No thanks")
    end

    it "raises when the token is invalid" do
      stub_chat_for_follow_up
      runner = described_class.new(user: admin)

      expect { runner.run_rejected(token: "bad") }.to raise_error(ArgumentError, "invalid approval token")
    end
  end
end
