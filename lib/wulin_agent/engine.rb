# frozen_string_literal: true

require "rails"
require "wulin_agent/extensions/grid_agent_actions"

module WulinAgent
  class Engine < ::Rails::Engine
    config.to_prepare do

      ToolRegistry.reset!
      Catalog.reset!

      WulinMaster::Grid.include WulinAgent::Extensions::GridAgentActions

      WulinMaster::ScreenController.prepend_view_path(
        WulinAgent::Engine.root.join("app/views")
      )
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

    initializer "wulin_agent.ruby_llm" do
      RubyLLM.configure do |config|
        config.openai_api_key ||= ENV["OPENAI_API_KEY"]
        config.use_new_acts_as = true
      end
    end
  end
end
