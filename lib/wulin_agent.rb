# frozen_string_literal: true

require "wulin_agent/version"
require "wulin_agent/engine" if defined?(Rails) && Rails::VERSION::MAJOR >= 5

module WulinAgent
  def self.setup(&_block)
    yield self
  end
end
