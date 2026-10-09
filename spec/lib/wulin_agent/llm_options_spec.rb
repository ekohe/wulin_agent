# frozen_string_literal: true

require "rails_helper"

RSpec.describe "WulinAgent.apply_llm_options_from_env!" do
  around do |example|
    saved = ENV.to_h.slice("WULIN_AGENT_TEMPERATURE", "WULIN_AGENT_THINKING")
    config = WulinAgent.config
    previous = [config.temperature, config.thinking_effort]
    example.run
  ensure
    %w[WULIN_AGENT_TEMPERATURE WULIN_AGENT_THINKING].each { |key| ENV[key] = saved[key] }
    config.temperature, config.thinking_effort = previous
  end

  it "keeps the values an initializer set when the variables are unset" do
    ENV.delete("WULIN_AGENT_TEMPERATURE")
    ENV.delete("WULIN_AGENT_THINKING")
    WulinAgent.config.temperature = 0.3
    WulinAgent.config.thinking_effort = "high"

    WulinAgent.apply_llm_options_from_env!

    expect(WulinAgent.config.temperature).to eq(0.3)
    expect(WulinAgent.config.thinking_effort).to eq("high")
  end

  it "lets the variables override the initializer" do
    ENV["WULIN_AGENT_TEMPERATURE"] = "0.9"
    ENV["WULIN_AGENT_THINKING"] = "low"
    WulinAgent.config.temperature = 0.3
    WulinAgent.config.thinking_effort = "high"

    WulinAgent.apply_llm_options_from_env!

    expect(WulinAgent.config.temperature).to eq(0.9)
    expect(WulinAgent.config.thinking_effort).to eq("low")
  end
end
