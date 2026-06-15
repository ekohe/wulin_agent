# frozen_string_literal: true

require "rails"
require "wulin_agent/extensions/grid_agent_actions"

module WulinAgent
  class Engine < ::Rails::Engine
    config.to_prepare do
      WulinMaster::Grid.include WulinAgent::Extensions::GridAgentActions
    end
    initializer :append_migrations do |app|
      config.paths["db/migrate"].expanded.each do |migration_path|
        app.config.paths["db/migrate"] << migration_path
      end
    end
  end
end
