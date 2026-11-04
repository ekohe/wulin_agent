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

    # Same as every wulin component: a plain db:migrate picks these up. Hosts
    # that copied them with the old install:migrations keep their copies.
    initializer :append_migrations do |app|
      copied = Dir[app.root.join("db/migrate/*.wulin_agent_engine.rb")].any?
      unless app.root.to_s.match(root.to_s) || copied
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end

    initializer "wulin_agent.ruby_llm" do |app|
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

          openrouter = Rails.application.credentials[:openrouter]
          config.openrouter_api_key ||= ENV["OPENROUTER_API_KEY"].presence ||
            openrouter&.dig(:access_token) || openrouter&.dig(:api_key)

          config.default_model = WulinAgent.model_from_env

          WulinAgent.apply_llm_options_from_env!

          # config.logger = Rails.logger
          # config.log_level = Logger::DEBUG
        end

        # In the server only: the lookup loads ruby_llm's whole model registry (a quarter of a second),
        # and every other boot -- a migration, `rails runner`, the console -- would pay it for a warning
        # nobody serving chats reads.
        if defined?(Rails::Server) && (model = WulinAgent.unknown_model)
          on = WulinAgent.provider ? " on #{WulinAgent.provider}" : ""
          Rails.logger.warn("[wulin_agent] WULIN_AGENT_MODEL=#{model} is not a model ruby_llm knows#{on}: " \
            "every chat will fail until it names one")
        end
      end
    end
  end
end
