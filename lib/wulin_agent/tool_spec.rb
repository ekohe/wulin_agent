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
    :callable
  ) do
    def execute(params = {}, user = nil, approval_mode: :confirm_writes, approved: false)
      if Approvals.needs_approval?(self, mode: approval_mode, approved: approved)
        {
          "status" => "approval_required",
          "tool" => name,
          "params" => params,
          "summary" => description
        }
      else
        callable.call(params, user)
      end
    end
  end

  def self.tool_name(controller, operation)
    "#{controller}__#{operation}"
  end
end
