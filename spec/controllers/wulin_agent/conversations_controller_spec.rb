# frozen_string_literal: true

require "rails_helper"

RSpec.describe WulinAgent::ConversationsController, type: :controller do
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
    allow(runner).to receive(:run) do |_message, archive_id: nil, &block|
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
      }.to change(WulinAgent::Conversation, :count).by(1)
        .and change(WulinAgent::Message, :count).by(2)

      conversation = WulinAgent::Conversation.last
      expect(conversation.user).to eq(user)
      expect(conversation.approval_mode).to eq("confirm_writes")
      expect(conversation.messages.chronological.pluck(:role, :content)).to eq(
        [["user", "How many people?"], ["assistant", "There are 0 people."]]
      )
    end

    it "creates a conversation with the requested approval_mode" do
      stub_runner_run(content: "OK")

      post :create, params: {message: "Hello", approval_mode: "confirm_all"}

      expect(WulinAgent::Conversation.last.approval_mode).to eq("confirm_all")
      expect(WulinAgent::Runner).to have_received(:new).with(
        hash_including(approval_mode: :confirm_all)
      )
    end

    it "reuses an existing conversation" do
      conversation = WulinAgent::Conversation.create!(user: user)
      stub_runner_run(content: "OK")

      expect {
        post :create, params: {conversation_id: conversation.id, message: "Again"}
      }.not_to change(WulinAgent::Conversation, :count)

      expect(conversation.messages.count).to eq(2)
    end

    it "streams a data-stream response" do
      stub_runner_run(content: "Hi", chunks: ["Hi"])

      post :create, params: {message: "Hello"}

      expect(response.body).to include('0:"Hi"')
      expect(response.body).to include("[DONE]")
      expect(response.media_type).to eq("text/plain")
      expect(response.headers["X-Conversation-Id"]).to eq(WulinAgent::Conversation.last.id.to_s)
      expect(WulinAgent::Conversation.last.status).to eq("idle")
    end

    it "marks the conversation running during the stream" do
      conversation = nil
      allow(runner).to receive(:run) do |_message, archive_id: nil, &block|
        conversation = WulinAgent::Conversation.last
        expect(conversation.status).to eq("running")
        block&.call(type: :text_delta, content: "Hi")
        block&.call(type: :done)
        "Hi"
      end

      post :create, params: {message: "Hello"}

      expect(conversation.reload.status).to eq("idle")
    end

    it "accepts an archive-only turn and stores archive metadata" do
      stub_runner_run(content: "Archive received.")

      post :create, params: {archive_id: "abc-123"}

      expect(response).to have_http_status(:ok)
      expect(runner).to have_received(:run).with("", archive_id: "abc-123")
      user_message = WulinAgent::Conversation.last.messages.chronological.first
      expect(user_message.content).to eq("")
      expect(user_message.metadata).to include("archive_id" => "abc-123")
      expect(user_message.metadata["inject_mode"]).to eq("error")
    end

    it "rejects a create turn with no message and no archive" do
      post :create, params: {message: ""}

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "passes prior history to the runner excluding the new user message" do
      conversation = WulinAgent::Conversation.create!(user: user)
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
      }.to change(WulinAgent::Message, :count).by(2)

      messages = WulinAgent::Conversation.last.messages.chronological
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
      conversation = WulinAgent::Conversation.create!(user: user)
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
      conversation = WulinAgent::Conversation.create!(user: user)
      conversation.messages.create!(role: "user", content: "Hi")
      conversation.messages.create!(role: "assistant", content: "Hello", metadata: {"tool_calls" => []})

      get :show, params: {id: conversation.id}

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload["id"]).to eq(conversation.id)
      expect(payload["status"]).to eq("idle")
      expect(payload["messages"].size).to eq(2)
      expect(payload["messages"].last["metadata"]).to eq({"tool_calls" => []})
    end

    it "does not expose another user's conversation" do
      other = User.create!(email: "other-#{SecureRandom.hex(4)}@example.com")
      conversation = WulinAgent::Conversation.create!(user: other)

      expect {
        get :show, params: {id: conversation.id}
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "DELETE #destroy" do
    it "destroys the conversation" do
      conversation = WulinAgent::Conversation.create!(user: user)
      conversation.messages.create!(role: "user", content: "Hi")

      expect {
        delete :destroy, params: {id: conversation.id}
      }.to change(WulinAgent::Conversation, :count).by(-1)
        .and change(WulinAgent::Message, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "does not expose another user's conversation" do
      other = User.create!(email: "other-#{SecureRandom.hex(4)}@example.com")
      conversation = WulinAgent::Conversation.create!(user: other)

      expect {
        delete :destroy, params: {id: conversation.id}
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "PATCH #update" do
    it "updates approval_mode" do
      conversation = WulinAgent::Conversation.create!(user: user)

      patch :update, params: {id: conversation.id, approval_mode: "auto"}

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload).to eq("id" => conversation.id, "approval_mode" => "auto")
      expect(conversation.reload.approval_mode).to eq("auto")
    end

    it "does not expose another user's conversation" do
      other = User.create!(email: "other-#{SecureRandom.hex(4)}@example.com")
      conversation = WulinAgent::Conversation.create!(user: other)

      expect {
        patch :update, params: {id: conversation.id, approval_mode: "auto"}
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "POST #approve" do
    it "streams the approved tool result and persists the assistant reply" do
      conversation = WulinAgent::Conversation.create!(user: user)
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
      conversation = WulinAgent::Conversation.create!(user: user)
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
      conversation = WulinAgent::Conversation.create!(user: user)
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
      conversation = WulinAgent::Conversation.create!(user: user)
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

  describe "POST #feedback" do
    let(:conversation) { WulinAgent::Conversation.create!(user: user) }
    let(:message) do
      conversation.messages.create!(
        role: "assistant",
        content: "Here you go",
        metadata: {"tool_calls" => [], "tool_results" => []}
      )
    end

    it "rejects an invalid rating" do
      post :feedback, params: {id: conversation.id, message_id: message.id, rating: "meh"}

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns not found when the message does not belong to the conversation" do
      post :feedback, params: {id: conversation.id, message_id: 0, rating: "up"}

      expect(response).to have_http_status(:not_found)
    end

    context "positive feedback" do
      let(:skill) { WulinAgent::Skill.create!(name: "saved", description: "d", instructions: "i") }

      it "records the rating, distills a skill and links it to the message" do
        allow(WulinAgent::SkillDistiller).to receive(:call).and_return(skill)

        post :feedback, params: {id: conversation.id, message_id: message.id, rating: "up"}

        expect(response).to have_http_status(:ok)
        payload = JSON.parse(response.body)
        expect(payload["rating"]).to eq("up")
        expect(payload["skill"]).to eq("name" => "saved", "description" => "d")
        expect(message.reload.rating).to eq("up")
        expect(message.metadata["skill_id"]).to eq(skill.id)
      end

      it "is idempotent: a second positive feedback does not distill again" do
        allow(WulinAgent::SkillDistiller).to receive(:call).and_return(skill)
        message.update!(metadata: message.metadata.merge("skill_id" => skill.id))

        post :feedback, params: {id: conversation.id, message_id: message.id, rating: "up"}

        expect(WulinAgent::SkillDistiller).not_to have_received(:call)
        expect(message.reload.metadata["skill_id"]).to eq(skill.id)
      end
    end

    context "negative feedback after a skill was created" do
      it "destroys the linked skill and clears the link" do
        skill = WulinAgent::Skill.create!(name: "to_delete", description: "d", instructions: "i")
        message.update!(metadata: message.metadata.merge("skill_id" => skill.id))

        post :feedback, params: {id: conversation.id, message_id: message.id, rating: "down"}

        expect(WulinAgent::Skill.find_by(id: skill.id)).to be_nil
        expect(message.reload.metadata).not_to have_key("skill_id")
        expect(message.reload.rating).to eq("down")
      end
    end
  end

  describe "POST #upload_archive" do
    def build_zip(entries)
      buffer = StringIO.new
      buffer.set_encoding(Encoding::BINARY)
      Zip::OutputStream.write_buffer(buffer) do |zip|
        entries.each do |path, content|
          zip.put_next_entry(path)
          zip.write(content)
        end
      end
      buffer.string
    end

    before { WulinAgent::ArchiveService.reset! }
    after { WulinAgent::ArchiveService.reset! }

    it "accepts a zip upload and returns the archive manifest" do
      file = Rack::Test::UploadedFile.new(
        StringIO.new(build_zip("docs/readme.md" => "# Hello")),
        "application/zip",
        original_filename: "export.zip"
      )

      post :upload_archive, params: {file: file}

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload["archive_id"]).to be_present
      expect(payload["file_count"]).to eq(1)
      expect(payload["inject_mode"]).to eq("full")
      expect(payload["inject_message"]).to include("Content included in the message")
    end

    it "accepts a single text file upload" do
      file = Rack::Test::UploadedFile.new(
        StringIO.new("hello"),
        "text/plain",
        original_filename: "notes.txt"
      )

      post :upload_archive, params: {file: file}

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload["archive_id"]).to be_present
      expect(payload["file_count"]).to eq(1)
    end

    it "rejects unsupported file types" do
      file = Rack::Test::UploadedFile.new(
        StringIO.new("binary"),
        "image/png",
        original_filename: "photo.png"
      )

      post :upload_archive, params: {file: file}

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to eq("error" => "file must be a .zip or a supported text file")
    end
  end
end
