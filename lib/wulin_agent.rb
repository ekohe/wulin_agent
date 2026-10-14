# frozen_string_literal: true

require "wulin_agent/version"
require "wulin_agent/column_descriptor"
require "wulin_agent/column_metadata"
require "wulin_agent/grid_descriptor"
require "wulin_agent/controller_resolver"
require "wulin_agent/catalog"
require "wulin_agent/grid_dispatcher"
require "wulin_agent/approvals"
require "wulin_agent/tool_spec"
require "wulin_agent/grid_access"
require "wulin_agent/meta_grid_tools"
require "wulin_agent/knowledge_tools"
require "wulin_agent/action_inferer"
require "wulin_agent/tool_registry"
require "wulin_agent/ast_param_extractor"
require "wulin_agent/tool_adapter"
require "wulin_agent/runner"
require "wulin_agent/data_stream_writer"
require "wulin_agent/action_scanner"
require "wulin_agent/schema_formatter"
require "wulin_agent/grid_result"
require "wulin_agent/skill_tools"
require "wulin_agent/skill_tool_sequence_sanitizer"
require "wulin_agent/conversation_distiller"
require "wulin_agent/skill_distiller"
require "wulin_agent/mcp_adapter"
require "wulin_agent/chart_tools"
require "wulin_agent/archive_service"
require "wulin_agent/model_naming"
require "wulin_agent/configuration"
require "wulin_agent/engine" if defined?(Rails) && Rails::VERSION::MAJOR >= 5

module WulinAgent
  DEFAULT_MODEL = "gpt-6-luna"

  # Through OpenRouter whenever its key is configured: one key reaches every
  # vendor's models, and a platform can issue each app a key of its own with a
  # spending limit. Named on every chat, because left to the registry an
  # OpenRouter id ("openai/gpt-6-luna") resolves to another provider listing the
  # same one. The model keeps its usual name: ruby_llm maps "gpt-6-luna" to
  # OpenRouter's "openai/gpt-6-luna" itself.
  def self.provider
    :openrouter if RubyLLM.config.openrouter_api_key.present?
  end

  # WULIN_AGENT_MODEL, or the default when it is unset or empty: compose passes
  # an empty .env entry through as "", which is not a model.
  def self.model_from_env
    ENV["WULIN_AGENT_MODEL"].presence || DEFAULT_MODEL
  end

  # The configured model when ruby_llm cannot resolve it for the provider in use:
  # every chat then fails with ModelNotFoundError, so the engine says so at boot.
  # Not refused there -- the registry can lag a model the provider already serves.
  def self.unknown_model
    model = RubyLLM.config.default_model
    RubyLLM.models.find(model, **{provider: provider&.to_s}.compact)
    nil
  rescue RubyLLM::ModelNotFoundError
    model
  end

  # What every RubyLLM.chat here is called with.
  def self.chat_options(model = current_model)
    {model: model, provider: provider}.compact
  end

  def self.config
    @config ||= Configuration.new
  end

  def self.setup
    yield config if block_given?
  end

  def self.current_model
    RubyLLM.config.default_model
  end

  def self.apply_llm_options_from_env!
    if (temperature = ENV["WULIN_AGENT_TEMPERATURE"]).present?
      config.temperature = Float(temperature)
    end

    if (thinking = ENV["WULIN_AGENT_THINKING"]).present?
      config.thinking_effort = thinking
    end
  end
end
