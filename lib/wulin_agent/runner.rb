# frozen_string_literal: true

require "ruby_llm"
require "wulin_agent/tool_adapter"
require "wulin_agent/tool_registry"

module WulinAgent
  class Runner
    def initialize(user:, model: nil, approval_mode: :confirm_writes)
      @user = user
      @model = model
      @approval_mode = approval_mode
    end

    def run(message)
      RubyLLM.chat(model: @model).with_tools(*tools).ask(message).content
    end

    def tools
      @tools ||= ToolAdapter.build(
        ToolRegistry.for(@user),
        user: @user,
        approval_mode: @approval_mode
      )
    end
  end
end
