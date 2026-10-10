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

  # WULIN_AGENT_MODEL, or the default when it is unset or empty: compose passes
  # an empty .env entry through as "", which is not a model.
  def self.model_from_env
    ENV["WULIN_AGENT_MODEL"].presence || DEFAULT_MODEL
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
