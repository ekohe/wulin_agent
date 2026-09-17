# frozen_string_literal: true

module WulinAgent
  class Configuration
    attr_accessor :temperature, :thinking_effort

    def initialize
      @extra_tool_builders = []
    end

    # Lambdas registered by the host app: ->(user) { [ToolSpec, ...] }
    # Use controller: :host on each ToolSpec.
    attr_reader :extra_tool_builders
  end
end
