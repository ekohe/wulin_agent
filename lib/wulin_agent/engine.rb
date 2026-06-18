# frozen_string_literal: true

require "rails"
require "wulin_agent/extensions/grid_agent_actions"

module WulinAgent
  class Engine < ::Rails::Engine
    config.to_prepare do
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
      config.paths["db/migrate"].expanded.each do |migration_path|
        app.config.paths["db/migrate"] << migration_path
      end
    end
  end
end
