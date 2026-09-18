# frozen_string_literal: true

require "rails"
require "wulin_agent/extensions/grid_agent_actions"

module WulinAgent
  class Engine < ::Rails::Engine
    config.to_prepare do
      ControllerResolver.reset!
      ToolRegistry.reset!
      Catalog.reset!

      WulinMaster::Grid.include WulinAgent::Extensions::GridAgentActions
    end

    initializer "wulin_agent.assets" do |app|
      builds_path = root.join("app/assets/builds")
      app.config.assets.paths << builds_path
      app.config.assets.precompile += %w[wulin_agent.js wulin_agent.css]
    end

    initializer "wulin_agent.ruby_llm" do |app|
      RubyLLM.configure do |config|
        config.use_new_acts_as = true
      end

      app.config.after_initialize do
        RubyLLM.configure do |config|
          openai = Rails.application.credentials[:openai]
          config.openai_organization_id ||= openai&.dig(:organization_id)
          config.openai_project_id ||= openai&.dig(:project_id)
          config.openai_api_key ||= ENV["OPENAI_API_KEY"].presence ||
            openai&.dig(:access_token) || openai&.dig(:api_key)
          anthropic = Rails.application.credentials[:anthropic]
          config.anthropic_api_key ||= ENV["ANTHROPIC_API_KEY"].presence ||
            anthropic&.dig(:access_token) || anthropic&.dig(:api_key)
          gemini = Rails.application.credentials[:gemini]
          config.gemini_api_key ||= ENV["GEMINI_API_KEY"].presence ||
            gemini&.dig(:access_token) || gemini&.dig(:api_key)

          config.default_model = ENV.fetch("WULIN_AGENT_MODEL", WulinAgent::DEFAULT_MODEL)

          WulinAgent.apply_llm_options_from_env!

          # config.logger = Rails.logger
          # config.log_level = Logger::DEBUG
        end
      end
    end
  end
end
