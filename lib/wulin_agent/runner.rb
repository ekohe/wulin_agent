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

    def run(message)
      scope_messages_for_completion!
      chat.ask(message).content
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
  end
end
