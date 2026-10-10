# frozen_string_literal: true

require "rails_helper"
require "ruby_llm"

RSpec.describe WulinAgent::Runner do
  let(:admin) { User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", admin: true) }

  before do
    WulinAgent::Catalog.reset!
    WulinAgent::ToolRegistry.reset!
    load_dummy_grids
  end

  # ruby_llm builds a chat only for a configured provider; no request is sent.
  around do |example|
    keys = %i[openai_api_key anthropic_api_key].to_h { |key| [key, RubyLLM.config.public_send(key)] }
    keys.each_key { |key| RubyLLM.config.public_send(:"#{key}=", "test-key") }
    example.run
  ensure
    keys.each { |key, value| RubyLLM.config.public_send(:"#{key}=", value) }
  end

  # A real RubyLLM::Chat whose model replies are scripted, so the conversation
  # loop, tool execution and approval pauses are ruby_llm's own. Each reply is
  # {content:, chunks:, tool_calls: [{id:, name:, arguments:}]} or {raise:}.
  # Returns the messages the model was asked with, one array per request;
  # the chats it built are in @chats.
  def script_model(*replies)
    requests = []
    @chats = []
    allow(RubyLLM).to receive(:chat).and_wrap_original do |original, **options|
      original.call(**options).tap do |chat|
        @chats << chat
        allow(chat).to receive(:with_tool_options).and_call_original
        allow(chat).to receive(:with_temperature).and_call_original
        allow(chat).to receive(:with_thinking).and_return(chat)
        allow(chat).to receive(:generate) do |&block|
          requests << chat.messages.dup
          reply = replies.shift or raise "the model was asked more often than scripted"
          raise reply[:raise] if reply[:raise]

          Array(reply[:chunks]).each { |text| block&.call(RubyLLM::Chunk.new(role: :assistant, content: text)) }
          calls = Array(reply[:tool_calls]).to_h { |call| [call[:id], RubyLLM::ToolCall.new(**call)] }
          chat.add_message(role: :assistant, content: reply[:content].to_s, tool_calls: calls.presence)
        end
      end
    end
    requests
  end

  # What ConversationsController replays after a turn paused for approval.
  def paused_turn(call_id, tool, arguments, token)
    [
      {role: :user, content: "Please #{tool}"},
      {
        role: :assistant,
        content: "",
        metadata: {
          "tool_calls" => [{"id" => call_id, "name" => tool, "arguments" => arguments}],
          "tool_results" => [{"id" => call_id, "name" => tool,
                              "result" => {"status" => "approval_required", "approval_token" => token}}]
        }
      }
    ]
  end

  def tool_message(messages, call_id)
    message = messages.find { |msg| msg.tool_result? && msg.tool_call_id == call_id }
    JSON.parse(message.content.to_s)
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
      list = runner.tools.find { |t| t.name == "list_records" }

      expect(destroy.requires_approval?).to be(true)
      expect(list.requires_approval?).to be(false)
    end
  end

  describe "#run" do
    it "asks the model with the user's tools, one tool call per response" do
      requests = script_model({content: "There are 0 people."})

      runner = described_class.new(user: admin)
      response = runner.run("How many people?")

      expect(RubyLLM).to have_received(:chat).with(model: RubyLLM.config.default_model)
      expect(response).to eq("There are 0 people.")
      expect(requests.first.last.content).to eq("How many people?")
      expect(requests.first.first.role).to eq(:system)
    end

    it "uses an explicit model when passed" do
      script_model({content: "ok"})

      described_class.new(user: admin, model: "claude-sonnet-5-5").run("hi")

      expect(RubyLLM).to have_received(:chat).with(model: "claude-sonnet-5-5")
    end

    describe "temperature and thinking from WulinAgent config" do
      after do
        WulinAgent.config.temperature = nil
        WulinAgent.config.thinking_effort = nil
      end

      it "sends temperature to a model that takes it" do
        script_model({content: "ok"})
        WulinAgent.config.temperature = 0.7

        described_class.new(user: admin, model: "gpt-4.1").run("hi")

        expect(@chats.first).to have_received(:with_temperature).with(0.7)
        expect(@chats.first).to have_received(:with_tool_options).with(calls: :one)
      end

      it "leaves temperature out for a model the registry says does not take it" do
        script_model({content: "ok"})
        WulinAgent.config.temperature = 0.7
        WulinAgent.config.thinking_effort = "high"
        allow(Rails.logger).to receive(:warn)

        described_class.new(user: admin).run("hi")

        expect(@chats.first).not_to have_received(:with_temperature)
        expect(@chats.first).to have_received(:with_thinking).with(effort: "high")
        expect(Rails.logger).to have_received(:warn).with(/gpt-6-luna does not take temperature/)
      end

      it "leaves out a thinking effort the model does not offer" do
        script_model({content: "ok"})
        WulinAgent.config.thinking_effort = "none"
        allow(Rails.logger).to receive(:warn)

        described_class.new(user: admin, model: "gpt-6.1-sol").run("hi")

        expect(@chats.first).not_to have_received(:with_thinking)
        expect(Rails.logger).to have_received(:warn).with(/gpt-6.1-sol takes thinking effort low\/.*, not none/)
      end

      it "sends both as set to a model the registry does not describe" do
        WulinAgent.config.temperature = 0.7
        WulinAgent.config.thinking_effort = "high"
        chat = RubyLLM.chat(model: "my-finetune", provider: :openai, assume_model_exists: true)

        described_class.new(user: admin).send(:apply_llm_options, chat)

        expect(chat.temperature).to eq(0.7)
        expect(chat.thinking).to eq(effort: :high)
      end
    end

    it "keeps the system prompt and only the last #{described_class::MAX_CONTEXT_MESSAGES} history messages" do
      history = (1..(described_class::MAX_CONTEXT_MESSAGES + 2)).map { |i| {role: :user, content: "msg #{i}"} }
      requests = script_model({content: "ok"})

      described_class.new(user: admin, history: history).run("next")

      asked = requests.first
      expect(asked.first.role).to eq(:system)
      expect(asked.drop(1).map(&:content))
        .to eq(history.last(described_class::MAX_CONTEXT_MESSAGES).map { |m| m[:content] } + ["next"])
    end

    it "yields text_delta and done events when a block is given" do
      script_model({content: "Done.", chunks: ["There ", "are 2."]})

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

    it "runs a read tool and yields correlated tool_call and tool_result events" do
      script_model(
        {tool_calls: [{id: "call_abc", name: "list_records", arguments: {"controller" => "people", "offset" => 0}}]},
        {content: "There are 0 people.", chunks: ["Checking..."]}
      )

      events = []
      described_class.new(user: admin).run("How many people?") { |event| events << event }

      expect(events).to include(
        hash_including(type: :tool_call, id: "call_abc", name: "list_records"),
        hash_including(type: :tool_result, id: "call_abc", name: "list_records"),
        {type: :text_delta, content: "Checking..."},
        {type: :done}
      )
    end

    it "pauses before a write tool, issues an approval grant and does not run it" do
      script_model(
        {tool_calls: [{id: "call_create", name: "create_record",
                       arguments: {"controller" => "people", "attributes" => {"first_name" => "AMOGUS"}}}]}
      )

      events = []
      response = described_class.new(user: admin).run("create AMOGUS") { |event| events << event }

      expect(response).to eq("")
      expect(events).to include(hash_including(type: :tool_call, id: "call_create", name: "create_record"))
      result = events.find { |event| event[:type] == :tool_result }
      expect(result).to include(id: "call_create", name: "create_record")
      expect(result[:result]).to include("status" => "approval_required", "tool" => "create_record")
      expect(WulinAgent::Approvals.fetch!(result[:approval_token], user_id: admin.id))
        .to include(tool: "create_record", tool_call_id: "call_create")
      expect(Person.where(first_name: "AMOGUS")).to be_empty
      expect(events).not_to include(hash_including(type: :text_delta))
      expect(events.last).to eq(type: :done)
    end
  end

  describe "#run_approved" do
    it "executes the approved tool and streams the follow-up response" do
      alice = Person.create!(first_name: "Alice", last_name: "Martin")
      arguments = {"controller" => "people", "id" => alice.id}
      token = WulinAgent::Approvals.issue!(tool: "destroy_record", params: arguments, user_id: admin.id, tool_call_id: "call_1")
      requests = script_model({content: "Done.", chunks: ["OK"]})

      events = []
      runner = described_class.new(user: admin, history: paused_turn("call_1", "destroy_record", arguments, token))
      response = runner.run_approved(token: token) { |event| events << event }

      expect(Person.find_by(id: alice.id)).to be_nil
      expect(response).to eq("Done.")
      expect(events).to include(
        {type: :tool_result, id: "call_1", name: "destroy_record", result: {"success" => true}},
        {type: :text_delta, content: "OK"},
        {type: :done}
      )
      expect(tool_message(requests.first, "call_1")).to eq("success" => true)
    end

    it "runs the tool with the params the user confirmed" do
      Person.create!(first_name: "Alice", last_name: "Martin")
      proposed = {"controller" => "people", "attributes" => {"first_name" => "Bob"}}
      token = WulinAgent::Approvals.issue!(tool: "create_record", params: proposed, user_id: admin.id, tool_call_id: "call_1")
      script_model({content: "Created."})

      runner = described_class.new(user: admin, history: paused_turn("call_1", "create_record", proposed, token))
      runner.run_approved(token: token, params: {"controller" => "people", "attributes" => {"first_name" => "Carol"}})

      expect(Person.where(first_name: "Carol")).to exist
      expect(Person.where(first_name: "Bob")).not_to exist
    end

    it "raises when the token is invalid" do
      script_model
      runner = described_class.new(user: admin)

      expect { runner.run_approved(token: "bad") }.to raise_error(ArgumentError, "invalid approval token")
    end

    it "claims the grant before a tool runs and cannot replay it after a model failure" do
      token = WulinAgent::Approvals.issue!(tool: "list_grids", params: {}, user_id: admin.id, tool_call_id: "call_1")
      script_model({raise: "model unavailable"})
      spec = WulinAgent::ToolRegistry.find("list_grids", admin)
      allow(WulinAgent::ToolRegistry).to receive(:find).with("list_grids", admin).and_return(spec)
      expect(spec).to receive(:execute).once.and_wrap_original do |execute, *args, **options|
        expect(WulinAgent::Approvals.fetch!(token, user_id: admin.id)).to be_nil
        execute.call(*args, **options)
      end
      runner = described_class.new(user: admin, history: paused_turn("call_1", "list_grids", {}, token))

      expect { runner.run_approved(token: token) }.to raise_error("model unavailable")
      expect { runner.run_approved(token: token) }.to raise_error(ArgumentError, "invalid approval token")
    end

    it "executes tools that require no params" do
      token = WulinAgent::Approvals.issue!(tool: "list_grids", params: {}, user_id: admin.id, tool_call_id: "call_1")
      script_model({content: "Done."})

      events = []
      runner = described_class.new(user: admin, history: paused_turn("call_1", "list_grids", {}, token))
      response = runner.run_approved(token: token) { |event| events << event }

      expect(response).to eq("Done.")
      expect(events).to include(hash_including(type: :tool_result, name: "list_grids"))
    end

    it "continues the agent turn and pauses again at the next write" do
      alice = Person.create!(first_name: "Alice", last_name: "Martin")
      token = WulinAgent::Approvals.issue!(tool: "list_records", params: {"controller" => "people"},
        user_id: admin.id, tool_call_id: "call_list")
      script_model(
        {tool_calls: [{id: "call_destroy", name: "destroy_record", arguments: {"controller" => "people", "id" => alice.id}}]}
      )

      events = []
      history = paused_turn("call_list", "list_records", {"controller" => "people"}, token)
      response = described_class.new(user: admin, history: history).run_approved(token: token) { |event| events << event }

      expect(response).to eq("")
      expect(events).to include(
        hash_including(type: :tool_result, id: "call_list", name: "list_records"),
        hash_including(type: :tool_call, id: "call_destroy", name: "destroy_record"),
        hash_including(type: :tool_result, id: "call_destroy", name: "destroy_record", approval_token: a_kind_of(String))
      )
      expect(Person.find_by(id: alice.id)).to eq(alice)
      expect(events).not_to include(hash_including(type: :text_delta))
    end
  end

  describe "#run_rejected" do
    it "invalidates the token, tells the model, and streams the follow-up response" do
      alice = Person.create!(first_name: "Alice", last_name: "Martin")
      arguments = {"controller" => "people", "id" => alice.id}
      token = WulinAgent::Approvals.issue!(tool: "destroy_record", params: arguments, user_id: admin.id, tool_call_id: "call_1")
      requests = script_model({content: "Understood.", chunks: ["OK"]})

      events = []
      runner = described_class.new(user: admin, history: paused_turn("call_1", "destroy_record", arguments, token))
      response = runner.run_rejected(token: token) { |event| events << event }

      expect(Person.find_by(id: alice.id)).to eq(alice)
      expect(response).to eq("Understood.")
      expect(events).to eq([{type: :text_delta, content: "OK"}, {type: :done}])
      expect(tool_message(requests.first, "call_1"))
        .to include("status" => "rejected", "reason" => "User declined destroy_record")
      expect(WulinAgent::Approvals.consume!(token, user_id: admin.id)).to be_nil
    end

    it "uses a custom rejection reason" do
      token = WulinAgent::Approvals.issue!(tool: "destroy_record", params: {"controller" => "people", "id" => 1},
        user_id: admin.id, tool_call_id: "call_1")
      requests = script_model({content: "OK"})

      runner = described_class.new(user: admin,
        history: paused_turn("call_1", "destroy_record", {"controller" => "people", "id" => 1}, token))
      runner.run_rejected(token: token, reason: "No thanks")

      expect(tool_message(requests.first, "call_1")).to include("status" => "rejected", "reason" => "No thanks")
    end

    it "raises when the token is invalid" do
      script_model
      runner = described_class.new(user: admin)

      expect { runner.run_rejected(token: "bad") }.to raise_error(ArgumentError, "invalid approval token")
    end
  end
end
