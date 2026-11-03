# frozen_string_literal: true

module WulinAgent
  class Configuration
    attr_accessor :temperature, :thinking_effort, :toolbar_enabled, :mcp_allowed_hosts, :approval_grant_class

    # Hash: grid controller name => column names omitted from list_records when the
    # agent does not pass fields or omit_columns. Columns remain visible in get_columns;
    # pass fields (including omitted names) to return them.
    attr_accessor :list_records_default_omit_columns
    # Truncate string cell values in projected list rows (nil = no truncation unless text_max_chars param).
    attr_accessor :list_records_text_max_chars
    # When true, list_records keeps sql/query metadata in the JSON response.
    attr_accessor :list_records_debug_metadata

    def initialize
      @extra_tool_builders = []
      @toolbar_enabled = true
      @mcp_allowed_hosts = []
      @approval_grant_class = "WulinAgent::ApprovalGrant"
      @list_records_default_omit_columns = {}
      @list_records_text_max_chars = nil
      @list_records_debug_metadata = false
    end

    def default_omit_columns_for(controller)
      Array(list_records_default_omit_columns[controller.to_s]).map(&:to_s).reject(&:empty?)
    end

    # Lambdas registered by the host app: ->(user) { [ToolSpec, ...] }
    # Use controller: :host on each ToolSpec.
    attr_reader :extra_tool_builders
  end
end
