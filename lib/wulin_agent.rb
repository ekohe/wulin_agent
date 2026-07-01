# frozen_string_literal: true

require "wulin_agent/version"
require "wulin_agent/column_descriptor"
require "wulin_agent/grid_descriptor"
require "wulin_agent/controller_resolver"
require "wulin_agent/catalog"
require "wulin_agent/grid_dispatcher"
require "wulin_agent/approvals"
require "wulin_agent/tool_spec"
require "wulin_agent/grid_access"
require "wulin_agent/standard_grid_tools"
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
require "wulin_agent/conversation_distiller"
require "wulin_agent/skill_distiller"
require "wulin_agent/mcp_adapter"
require "wulin_agent/chart_tools"
require "wulin_agent/model_naming"
require "wulin_agent/engine" if defined?(Rails) && Rails::VERSION::MAJOR >= 5

module WulinAgent
  DEFAULT_MODEL = "gpt-4o-mini"

  def self.setup
    yield self if block_given?
  end

  def self.current_model
    RubyLLM.config.default_model
  end
end
