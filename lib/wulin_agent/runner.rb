# frozen_string_literal: true

require "ruby_llm"
require "wulin_agent/tool_adapter"
require "wulin_agent/tool_registry"

module WulinAgent
  class Runner
    MAX_CONTEXT_MESSAGES = 10

    def initialize(user:, model: nil, approval_mode: :confirm_writes)
      @user = user
      @model = model
      @approval_mode = approval_mode
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
      RubyLLM.chat(model: @model)
        .with_tools(*tools)
        .with_instructions(system_prompt)
        .on_tool_call { |tc| emit_tool_call(tc) }
        .on_tool_result { |result| emit_tool_result(result) }
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
      emit(
        type: :tool_result,
        id: @current_tool_call&.id,
        name: @current_tool_call&.name,
        result: result
      )
      @current_tool_call = nil
    end

    def emit_text_delta(chunk)
      content = chunk.content
      return if content.nil? || content.to_s.empty?
    
      emit(type: :text_delta, content: content.to_s)
    end

  end
end
