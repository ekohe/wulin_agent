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

    initializer :append_migrations do |app|
      unless app.root.to_s.match root.to_s
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end

    initializer "wulin_agent.ruby_llm" do |app|
      RubyLLM.configure do |config|
        config.use_new_acts_as = true
      end

      app.config.after_initialize do
        RubyLLM.configure do |config|
          config.openai_api_key ||= ENV["OPENAI_API_KEY"].presence ||
            Rails.application.credentials.dig(:openai, :access_token)
        end
      end
    end
  end
end
