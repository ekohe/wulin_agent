# frozen_string_literal: true

require "rails_helper"

RSpec.describe Agent::ConversationsController, type: :controller do
  routes { Rails.application.routes }

  let(:user) { User.create!(email: "agent-#{SecureRandom.hex(4)}@example.com", admin: true) }
  let(:runner) { instance_double(WulinAgent::Runner) }

  before do
    PersonScreen
    PersonGrid
    allow(controller).to receive(:current_user).and_return(user)
    allow(WulinAgent::Runner).to receive(:new).and_return(runner)
  end

  def stub_runner_run(content: "Hi", chunks: [content])
    allow(runner).to receive(:run) do |_message, &block|
      chunks.each { |chunk| block&.call(type: :text_delta, content: chunk) }
      block&.call(type: :done)
      content
    end
  end

  describe "POST #create" do
    it "returns unauthorized without a current user" do
      allow(controller).to receive(:current_user).and_return(nil)

      post :create, params: {message: "Hello"}

      expect(response).to have_http_status(:unauthorized)
    end

    it "creates a conversation and persists user and assistant messages" do
      stub_runner_run(content: "There are 0 people.")

      expect {
        post :create, params: {message: "How many people?"}
      }.to change(Agent::Conversation, :count).by(1)
        .and change(Agent::Message, :count).by(2)

      conversation = Agent::Conversation.last
      expect(conversation.user).to eq(user)
      expect(conversation.approval_mode).to eq("confirm_writes")
      expect(conversation.messages.chronological.pluck(:role, :content)).to eq(
        [["user", "How many people?"], ["assistant", "There are 0 people."]]
      )
    end

    it "creates a conversation with the requested approval_mode" do
      stub_runner_run(content: "OK")

      post :create, params: {message: "Hello", approval_mode: "confirm_all"}

      expect(Agent::Conversation.last.approval_mode).to eq("confirm_all")
      expect(WulinAgent::Runner).to have_received(:new).with(
        hash_including(approval_mode: :confirm_all)
      )
    end

    it "reuses an existing conversation" do
      conversation = Agent::Conversation.create!(user: user)
      stub_runner_run(content: "OK")

      expect {
        post :create, params: {conversation_id: conversation.id, message: "Again"}
      }.not_to change(Agent::Conversation, :count)

      expect(conversation.messages.count).to eq(2)
    end

    it "streams a data-stream response" do
      stub_runner_run(content: "Hi", chunks: ["Hi"])

      post :create, params: {message: "Hello"}

      expect(response.body).to include('0:"Hi"')
      expect(response.body).to include("[DONE]")
      expect(response.media_type).to eq("text/plain")
      expect(response.headers["X-Conversation-Id"]).to eq(Agent::Conversation.last.id.to_s)
    end

    it "passes prior history to the runner excluding the new user message" do
      conversation = Agent::Conversation.create!(user: user)
      conversation.messages.create!(role: "user", content: "First")
      conversation.messages.create!(role: "assistant", content: "Earlier reply")
      stub_runner_run

      expect(WulinAgent::Runner).to receive(:new).with(
        hash_including(
          user: user,
          history: [{role: :user, content: "First"}, {role: :assistant, content: "Earlier reply"}]
        )
      ).and_return(runner)

      post :create, params: {conversation_id: conversation.id, message: "Second"}
    end

    it "persists an assistant message when the runner raises" do
      allow(runner).to receive(:run).and_raise(
        NoMethodError, "undefined method `split' for nil:NilClass"
      )

      expect {
        post :create, params: {message: "List stories"}
      }.to change(Agent::Message, :count).by(2)

      messages = Agent::Conversation.last.messages.chronological
      expect(messages.map(&:role)).to eq(%w[user assistant])
      expect(messages.last.content).to include("split")
    end

    it "streams the error as assistant text" do
      allow(runner).to receive(:run).and_raise(RuntimeError, "boom")

      post :create, params: {message: "Hello"}

      expect(response.body).to include('0:"Error : boom"')
      expect(response.body).not_to include('3:')
      expect(response.body).to include("[DONE]")
    end

    it "includes the error reply in history for the next turn" do
      conversation = Agent::Conversation.create!(user: user)
      conversation.messages.create!(role: "user", content: "First")
      conversation.messages.create!(role: "assistant", content: "OK")

      allow(runner).to receive(:run).and_raise(RuntimeError, "boom")
      post :create, params: {conversation_id: conversation.id, message: "Second"}

      messages = conversation.reload.messages.chronological
      expect(messages.last).to have_attributes(role: "assistant", content: "Error : boom")
    end
  end

  describe "GET #show" do
    it "returns the conversation messages as json" do
      conversation = Agent::Conversation.create!(user: user)
      conversation.messages.create!(role: "user", content: "Hi")
      conversation.messages.create!(role: "assistant", content: "Hello", metadata: {"tool_calls" => []})

      get :show, params: {id: conversation.id}

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload["id"]).to eq(conversation.id)
      expect(payload["messages"].size).to eq(2)
      expect(payload["messages"].last["metadata"]).to eq({"tool_calls" => []})
    end

    it "does not expose another user's conversation" do
      other = User.create!(email: "other-#{SecureRandom.hex(4)}@example.com")
      conversation = Agent::Conversation.create!(user: other)

      expect {
        get :show, params: {id: conversation.id}
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "PATCH #update" do
    it "updates approval_mode" do
      conversation = Agent::Conversation.create!(user: user)

      patch :update, params: {id: conversation.id, approval_mode: "auto"}

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload).to eq("id" => conversation.id, "approval_mode" => "auto")
      expect(conversation.reload.approval_mode).to eq("auto")
    end

    it "does not expose another user's conversation" do
      other = User.create!(email: "other-#{SecureRandom.hex(4)}@example.com")
      conversation = Agent::Conversation.create!(user: other)

      expect {
        patch :update, params: {id: conversation.id, approval_mode: "auto"}
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "POST #approve" do
    it "streams the approved tool result and persists the assistant reply" do
      conversation = Agent::Conversation.create!(user: user)
      allow(runner).to receive(:run_approved) do |**_args, &block|
        block&.call(type: :tool_result, name: "people__destroy", result: {"success" => true})
        block&.call(type: :text_delta, content: "Done.")
        block&.call(type: :done)
        "Done."
      end

      post :approve, params: {id: conversation.id, token: "tok-1"}

      expect(response.body).to include('"success":true')
      expect(response.headers["X-Conversation-Id"]).to eq(conversation.id.to_s)
      expect(conversation.messages.last).to have_attributes(
        role: "assistant",
        content: "Done."
      )
    end

    it "resolves the pending approval on the original assistant message" do
      conversation = Agent::Conversation.create!(user: user)
      conversation.messages.create!(
        role: "assistant",
        content: "",
        metadata: {
          "tool_calls" => [
            {"id" => "call_0", "name" => "list_grids", "arguments" => {}},
            {"id" => "call_1", "name" => "people__destroy", "arguments" => {"id" => 26}}
          ],
          "tool_results" => [
            {"id" => "call_0", "name" => "list_grids", "result" => [{"controller" => "people"}]},
            {
              "id" => "call_1",
              "name" => "people__destroy",
              "result" => {"status" => "approval_required", "approval_token" => "tok-1"}
            }
          ]
        }
      )
      allow(runner).to receive(:run_approved) do |**_args, &block|
        block&.call(type: :tool_result, name: "people__destroy", result: {"success" => true})
        block&.call(type: :text_delta, content: "Done.")
        block&.call(type: :done)
        "Done."
      end

      post :approve, params: {id: conversation.id, token: "tok-1"}

      expect(conversation.messages.chronological.first.metadata["tool_results"].last["result"]).to eq(
        "success" => true
      )
    end
  end

  describe "POST #reject" do
    it "streams the follow-up response" do
      conversation = Agent::Conversation.create!(user: user)
      allow(runner).to receive(:run_rejected) do |**_args, &block|
        block&.call(type: :text_delta, content: "Understood.")
        block&.call(type: :done)
        "Understood."
      end

      post :reject, params: {id: conversation.id, token: "tok-1", reason: "No thanks"}

      expect(response.body).to include('0:"Understood."')
      expect(conversation.messages.last.content).to eq("Understood.")
    end

    it "marks the pending approval as rejected on the original assistant message" do
      conversation = Agent::Conversation.create!(user: user)
      conversation.messages.create!(
        role: "assistant",
        content: "",
        metadata: {
          "tool_calls" => [{"id" => "call_1", "name" => "people__destroy", "arguments" => {"id" => 26}}],
          "tool_results" => [{
            "id" => "call_1",
            "name" => "people__destroy",
            "result" => {"status" => "approval_required", "approval_token" => "tok-1"}
          }]
        }
      )
      allow(runner).to receive(:run_rejected) do |**_args, &block|
        block&.call(type: :text_delta, content: "Understood.")
        block&.call(type: :done)
        "Understood."
      end

      post :reject, params: {id: conversation.id, token: "tok-1", reason: "No thanks"}

      expect(conversation.messages.chronological.first.metadata["tool_results"].first["result"]).to eq(
        "status" => "rejected",
        "reason" => "No thanks"
      )
    end
  end
end
