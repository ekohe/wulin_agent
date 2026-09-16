# frozen_string_literal: true

module WulinAgent
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

    def feedback
      conversation = user_conversations.find(params[:id])
      rating = params[:rating].to_s
      return head :unprocessable_entity unless %w[up down].include?(rating)
    
      message = rated_message(conversation)


      return head :not_found unless message
    
      message.update!(rating: rating)
      existing = WulinAgent::Skill.find_by(id: (message.metadata || {})["skill_id"])

      if rating == "up"
        skill = existing || WulinAgent::SkillDistiller.call(message: message, user: current_user)
        message.update!(metadata: message.metadata.merge("skill_id" => skill&.id))

        render json: {
        message_id: message.id,
        rating: message.rating,
        skill: skill&.as_json(only: %i[name description])
      }
      else # down
        existing&.destroy
        message.update!(metadata: message.metadata.except("skill_id"))
        render json: {message_id: message.id, rating: message.rating, skill: nil}
      end
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
          {id: message.id, role: message.role, content: message.content, metadata: message.metadata, rating: message.rating}
        end
      }
    end 

    def index
      conversations = user_conversations
      .includes(:messages)
      .order(updated_at: :desc)
      .limit(50)


      render json: conversations.map { |conversation|
        {
          id: conversation.id,
          title: conversation_title(conversation),
          updated_at: conversation.updated_at.iso8601,
          approval_mode: conversation.approval_mode
        }
      }
    end

    def agent_config
      render json: { model: WulinAgent.current_model }
    end

    def upload_archive
      result = ArchiveService.upload(file: params[:file], user: current_user)
      if result["error"]
        render json: result, status: :unprocessable_entity
      else
        render json: result
      end
    end

    private

    def conversation_title(conversation)
      conversation.title.presence ||
        conversation.messages.chronological.first&.content&.truncate(80) ||
        "Conversation ##{conversation.id}"
    end

    def stream_conversation_turn
      conversation = find_or_create_conversation
      if action_name == "create"
        return head :unprocessable_entity unless create_turn_valid?

        conversation.messages.create!(
          role: "user",
          content: message_param,
          metadata: user_message_metadata
        )
      end

      setup_stream_headers!(conversation)
      writer = WulinAgent::DataStreamWriter.new(response.stream)
      runner = build_runner(conversation)

      assistant_content = run_runner_turn(runner) { |event| writer.write(event) }

      resolve_pending_approval!(conversation, writer) if %w[approve reject].include?(action_name)

      message = conversation.messages.create!(
        role: "assistant",
        content: writer.assistant_text.presence || assistant_content.to_s,
        metadata: writer.metadata
      )
      writer.write_message_saved(message.id)
    rescue => e
      Rails.logger.error(
        "[wulin_agent] #{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}"
      )
      error_text = assistant_error_text(e)
      if writer
        writer.write(type: :text_delta, content: error_text)
        writer.close
      end
      conversation.messages.create!(
        role: "assistant",
        content: writer&.assistant_text.presence || error_text,
        metadata: writer&.metadata || {}
      )
    ensure
      response.stream.close
    end

    def run_runner_turn(runner, &on_event)
      case action_name
      when "create"
        runner.run(message_param, archive_id: params[:archive_id], &on_event)
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
        user_conversations.create!(approval_mode: approval_mode_for_create)
      end
    end

    def approval_mode_for_create
      mode = params[:approval_mode].to_s
      WulinAgent::Conversation::APPROVAL_MODES.include?(mode) ? mode : "confirm_writes"
    end

    def user_conversations
      WulinAgent::Conversation.where(user_id: current_user.id)
    end

    def assistant_error_text(error)
      message = error.message
      message = "Agent tool configuration error: #{message}" if error.is_a?(WulinAgent::ToolSchemaError)

      "Error : #{message}"
    end

    def message_param
      params[:message].to_s
    end

    def create_turn_valid?
      message_param.strip.present? || params[:archive_id].present?
    end

    def user_message_metadata
      archive_id = params[:archive_id].to_s.strip
      return {} if archive_id.empty?

      {"archive_id" => archive_id}.merge(
        ArchiveService.attachment_metadata(archive_id: archive_id, user: current_user)
      )
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

    def resolve_pending_approval!(conversation, writer)
      token = params[:token]
      return if token.blank?

      result =
        if action_name == "approve"
          writer.metadata["tool_results"]&.find { |tr| tr["result"].present? }&.dig("result")
        else
          {"status" => "rejected", "reason" => params[:reason].presence || "User declined"}
        end
      return unless result

      message = conversation.messages.chronological.reverse.find do |msg|
        msg.metadata.fetch("tool_results", []).any? do |tr|
          tool_result_approval_token(tr) == token
        end
      end
      return unless message

      tool_results = message.metadata["tool_results"].map do |tr|
        if tool_result_approval_token(tr) == token
          tr.merge("result" => result)
        else
          tr
        end
      end

      message.update!(metadata: message.metadata.merge("tool_results" => tool_results))
    end

    def tool_result_approval_token(tool_result)
      result = tool_result["result"]
      result["approval_token"] if result.is_a?(Hash)
    end

    def rated_message(conversation)
      return nil if params[:message_id].blank?

      conversation.messages.find_by(id: params[:message_id])
    end

  end
end
