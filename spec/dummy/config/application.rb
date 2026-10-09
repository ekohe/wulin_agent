require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)
require "dartsass-rails"
require "wulin_master"
require "wulin_permits"
require "wulin_agent"

module Dummy
  class Application < Rails::Application
    config.load_defaults 5.1

    # wulin_permits creates SQL views, which schema.rb cannot hold.
    config.active_record.schema_format = :sql
    # Hosts copy these with install:migrations; the dummy reads them in place.
    config.paths["db/migrate"] << WulinAgent::Engine.root.join("db/migrate").to_s
  end
end
