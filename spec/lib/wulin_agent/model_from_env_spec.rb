# frozen_string_literal: true

require "rails_helper"

RSpec.describe "WulinAgent.model_from_env" do
  around do |example|
    saved = ENV["WULIN_AGENT_MODEL"]
    key = RubyLLM.config.openai_api_key
    example.run
  ensure
    ENV["WULIN_AGENT_MODEL"] = saved
    RubyLLM.config.openai_api_key = key
  end

  it "defaults to gpt-6-luna" do
    ENV.delete("WULIN_AGENT_MODEL")

    expect(WulinAgent.model_from_env).to eq("gpt-6-luna")
  end

  it "treats an empty variable as unset, as compose passes an empty .env entry" do
    ENV["WULIN_AGENT_MODEL"] = ""

    expect(WulinAgent.model_from_env).to eq("gpt-6-luna")
  end

  it "uses the variable when it names a model" do
    ENV["WULIN_AGENT_MODEL"] = "claude-sonnet-4-6"

    expect(WulinAgent.model_from_env).to eq("claude-sonnet-4-6")
  end

  it "is what the engine configures ruby_llm with at boot" do
    expect(RubyLLM.config.default_model).to eq(WulinAgent.model_from_env)
  end

  it "names a model ruby_llm resolves to OpenAI" do
    RubyLLM.config.openai_api_key = "test-key"

    expect(RubyLLM.chat(model: WulinAgent::DEFAULT_MODEL).provider.slug).to eq("openai")
  end
end
