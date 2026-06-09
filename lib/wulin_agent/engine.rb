# frozen_string_literal: true

require "rails"

module WulinAgent
  class Engine < ::Rails::Engine
    initializer :append_migrations do |app|
      config.paths["db/migrate"].expanded.each do |migration_path|
        app.config.paths["db/migrate"] << migration_path
      end
    end
  end
end
