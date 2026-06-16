# frozen_string_literal: true

Rails.application.config.to_prepare do
  PersonScreen
  PersonGrid
  WulinAgent::Catalog.reset!
  WulinAgent::ToolRegistry.reset!
end
