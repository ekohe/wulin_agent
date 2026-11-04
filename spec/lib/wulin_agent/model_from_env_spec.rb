# frozen_string_literal: true

require "rails_helper"

RSpec.describe "WulinAgent.model_from_env" do
  around do |example|
    saved = ENV["WULIN_AGENT_MODEL"]
    key = RubyLLM.config.openai_api_key
    openrouter = RubyLLM.config.openrouter_api_key
    example.run
  ensure
    ENV["WULIN_AGENT_MODEL"] = saved
    RubyLLM.config.openai_api_key = key
    RubyLLM.config.openrouter_api_key = openrouter
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
    ENV["WULIN_AGENT_MODEL"] = "claude-sonnet-5-5"

    expect(WulinAgent.model_from_env).to eq("claude-sonnet-5-5")
  end

  it "is what the engine configures ruby_llm with at boot" do
    expect(RubyLLM.config.default_model).to eq(WulinAgent.model_from_env)
  end

  it "names a model ruby_llm resolves to OpenAI" do
    RubyLLM.config.openai_api_key = "test-key"

    expect(RubyLLM.chat(model: WulinAgent::DEFAULT_MODEL).provider.slug).to eq("openai")
  end

  context "with an OpenRouter key" do
    before do
      RubyLLM.config.openrouter_api_key = "test-key"
      ENV.delete("WULIN_AGENT_MODEL")
    end

    it "names OpenRouter on the chat, and asks it for the same model under its own id" do
      chat = RubyLLM.chat(**WulinAgent.chat_options(WulinAgent.model_from_env))

      expect([chat.provider.slug, chat.model.id]).to eq(%w[openrouter openai/gpt-6-luna])
    end

    # Left to the registry, an OpenRouter id resolves to another provider that lists the same one.
    it "keeps an OpenRouter id on OpenRouter" do
      expect(RubyLLM.chat(**WulinAgent.chat_options("openai/gpt-6-luna")).provider.slug).to eq("openrouter")
    end
  end

  it "names no provider without an OpenRouter key" do
    RubyLLM.config.openrouter_api_key = nil

    expect(WulinAgent.chat_options("gpt-6-luna")).to eq(model: "gpt-6-luna")
  end

  describe ".unknown_model" do
    around do |example|
      model = RubyLLM.config.default_model
      example.run
    ensure
      RubyLLM.config.default_model = model
    end

    it "is nil for a model ruby_llm resolves on the provider in use" do
      RubyLLM.config.openrouter_api_key = "test-key"
      RubyLLM.config.default_model = "claude-sonnet-5-5"

      expect(WulinAgent.unknown_model).to be_nil
    end

    it "names a model it cannot, which every chat would then fail on" do
      RubyLLM.config.default_model = "no-such-model"

      expect(WulinAgent.unknown_model).to eq("no-such-model")
    end
  end
end
