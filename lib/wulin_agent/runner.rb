# frozen_string_literal: true

require "ruby_llm"
require "wulin_agent/tool_adapter"
require "wulin_agent/tool_registry"

module WulinAgent
  class Runner
    MAX_CONTEXT_MESSAGES = 10

    def initialize(user:, model: nil, approval_mode: :confirm_writes, history: [])
      @user = user
      @model = model
      @approval_mode = approval_mode
      @history = history
    end

    def run(message, &block)
      @on_event = block
      scope_messages_for_completion!
      response = chat.ask(message) { |chunk| emit_text_delta(chunk) }
      emit(type: :done)
      response.content
    ensure
      @on_event = nil
    end

    def run_approved(token:, params: nil, &block)
      @on_event = block
      grant = Approvals.consume!(token, user_id: @user.id)
      raise ArgumentError, "invalid approval token" unless grant

      spec = ToolRegistry.find(grant[:tool], @user)
      raise ArgumentError, "tool not found" unless spec

      final_params = (params || grant[:params]).stringify_keys
      raise ArgumentError, "missing tool params" if final_params.empty?
      result = spec.execute(
        final_params,
        @user,
        approval_mode: @approval_mode,
        approved: true
      )

      emit(type: :tool_result, name: grant[:tool], result: result)

      chat.add_message(
        role: :user,
        content: "User approved #{grant[:tool]}: #{result.to_json}"
      )
      response = complete_summary_turn
      emit(type: :done)
      response.content
    ensure
      @on_event = nil
    end

    def run_rejected(token:, reason: nil, &block)
      @on_event = block
      grant = Approvals.consume!(token, user_id: @user.id)
      raise ArgumentError, "invalid approval token" unless grant
    
      message = reason || "User declined #{grant[:tool]}"
      chat.add_message(role: :user, content: message)

      response = complete_summary_turn
      emit(type: :done)
      response.content
    ensure
      @on_event = nil
    end

    def tools
      @tools ||= ToolAdapter.build(
        ToolRegistry.for(@user),
        user: @user,
        approval_mode: @approval_mode
      )
    end

    def messages
      chat.messages
    end

    def reset!
      @chat = nil
      @tools = nil
    end

    private

    def chat
      @chat ||= build_chat
    end

    def build_chat
      chat = RubyLLM.chat(model: @model)
        .with_tools(*tools)
        .with_instructions(system_prompt)
        .on_tool_call { |tc| emit_tool_call(tc) }
        .on_tool_result { |result| emit_tool_result(result) }
      @history.each { |msg| chat.add_message(role: msg[:role], content: msg[:content]) }
      chat
    end

    def system_prompt
      <<~PROMPT.strip
        You are a Wulin Master assistant. Use the available tools to read and
        modify grid data. Prefer tools over guessing. Be concise.
      PROMPT
    end

    def scope_messages_for_completion!
      if chat.respond_to?(:with_messages)
        chat.with_messages { |msgs| limited_messages(msgs) }
      else
        chat.instance_variable_set(:@messages, limited_messages(chat.messages))
      end
    end

    def complete_summary_turn
      scope_messages_for_completion!
      chat.with_tools(replace: true)
      chat.complete { |chunk| emit_text_delta(chunk) }
    ensure
      chat.with_tools(*tools, replace: true)
    end

    def limited_messages(messages)
      system, rest = messages.partition { |msg| msg.role == :system }
      system + rest.last(MAX_CONTEXT_MESSAGES)
    end

    def emit(event)
      @on_event&.call(event)
    end

    def emit_tool_call(tool_call)
      @current_tool_call = tool_call
      emit(type: :tool_call, id: tool_call.id, name: tool_call.name, arguments: tool_call.arguments)
    end
    
    def emit_tool_result(result)
      payload = {
        type: :tool_result,
        id: @current_tool_call&.id,
        name: @current_tool_call&.name,
        result: result
      }
      if result.is_a?(Hash) && result["status"] == "approval_required"
        params = result["params"].presence || @current_tool_call&.arguments || {}
        params = params.stringify_keys
        result = result.merge("params" => params)
        payload[:result] = result
        payload[:approval_token] = Approvals.issue!(
          tool: result["tool"],
          params: params,
          user_id: @user.id,
          tool_call_id: @current_tool_call&.id
        )
      end
      emit(payload)
      @current_tool_call = nil
    end

    def emit_text_delta(chunk)
      content = chunk.content
      return if content.nil? || content.to_s.empty?
    
      emit(type: :text_delta, content: content.to_s)
    end
  end
end
