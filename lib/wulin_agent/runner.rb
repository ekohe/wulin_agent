# frozen_string_literal: true

require "ruby_llm"

module WulinAgent
  class Runner
    def initialize(user:, model: nil)
      @user = user
      @model = model
    end

    def run(message)
      chat = RubyLLM.chat(model: @model)
      response = chat.ask(message)
      response.content
    end
  end
end
