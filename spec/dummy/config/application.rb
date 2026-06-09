require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)
require "wulin_agent"

module Dummy
  class Application < Rails::Application
    config.load_defaults 5.1
  end
end
