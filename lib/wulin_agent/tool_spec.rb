# frozen_string_literal: true

module WulinAgent
  ToolSpec = Struct.new(
    :name,
    :controller,
    :operation,
    :description,
    :params_schema,
    :mutating,
    :permission,
    :callable,
    keyword_init: true
  ) do
    def execute(params = {}, user = nil)
      callable.call(params, user)
    end
  end

  def self.tool_name(controller, operation)
    "#{controller}__#{operation}"
  end
end
