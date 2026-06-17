# frozen_string_literal: true

module Agent
  class ConversationsController < ApplicationController
    include ActionController::Live

    before_action :require_current_user!

    def create
      stream_conversation_turn
    end

    def approve
      stream_conversation_turn
    end

    def reject
      stream_conversation_turn
    end

    def update
      conversation = user_conversations.find(params[:id])
      conversation.update!(approval_mode: params.require(:approval_mode))
      render json: {id: conversation.id, approval_mode: conversation.approval_mode}
    end

    def show
      conversation = user_conversations.find(params[:id])
      render json: {
        id: conversation.id,
        approval_mode: conversation.approval_mode,
        messages: conversation.messages.chronological.map do |message|
          {role: message.role, content: message.content, metadata: message.metadata}
        end
      }
    end

    private

    def stream_conversation_turn
      conversation = find_or_create_conversation
      conversation.messages.create!(role: "user", content: message_param) if action_name == "create"

      setup_stream_headers!(conversation)
      writer = WulinAgent::DataStreamWriter.new(response.stream)
      runner = build_runner(conversation)

      assistant_content = run_runner_turn(runner) { |event| writer.write(event) }

      conversation.messages.create!(
        role: "assistant",
        content: writer.assistant_text.presence || assistant_content.to_s,
        metadata: writer.metadata
      )
    rescue => e
      writer&.write_error(e.message)
    ensure
      response.stream.close
    end

    def run_runner_turn(runner, &on_event)
      case action_name
      when "create"
        runner.run(message_param, &on_event)
      when "approve"
        runner.run_approved(token: params[:token], params: params[:params], &on_event)
      when "reject"
        runner.run_rejected(token: params[:token], reason: params[:reason], &on_event)
      end
    end

    def require_current_user!
      head :unauthorized unless current_user
    end

    def find_or_create_conversation
      if params[:conversation_id].present? || params[:id].present?
        user_conversations.find(params[:conversation_id].presence || params[:id])
      else
        user_conversations.create!
      end
    end

    def user_conversations
      Agent::Conversation.where(user_id: current_user.id)
    end

    def message_param
      params[:message].presence || params.require(:message)
    end

    def setup_stream_headers!(conversation)
      response.headers["Content-Type"] = "text/plain; charset=utf-8"
      response.headers["Cache-Control"] = "no-cache"
      response.headers["X-Accel-Buffering"] = "no"
      response.headers["X-Conversation-Id"] = conversation.id.to_s
    end

    def build_runner(conversation)
      WulinAgent::Runner.new(
        user: current_user,
        approval_mode: conversation.approval_mode_sym,
        history: conversation.history_for_runner(exclude_last: action_name == "create")
      )
    end
  end
end
