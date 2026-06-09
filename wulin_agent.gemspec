# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)
require "wulin_agent/version"
Gem::Specification.new do |s|
  s.name = "wulin_agent"
  s.version = WulinAgent::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ["Ekohe"]
  s.email = ["info@ekohe.com"]
  s.homepage = "http://rubygems.org/gems/wulin_agent"
  s.summary = "Conversational AI agent for Wulin Master apps"
  s.description = "Exposes Wulin Master grid operations as LLM tools with permission gating, " \
                  "via in-app chat (ruby_llm) and MCP."

  s.files = `git ls-files`.split("\n")
  s.executables = []
  s.require_paths = ["lib"]

  s.add_dependency "mcp"
  s.add_dependency "rails"
  s.add_dependency "ruby_llm"
  s.add_dependency "wulin_master"
  s.add_development_dependency "pg"
  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "standardrb"
end
