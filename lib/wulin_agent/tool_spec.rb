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
      # Refused before approval and before the tool, in every mode. Approving
      # a call that cannot run would change nothing, and auto mode should
      # hand the model the same reason.
      if (reason = schema_error(params))
        return {"error" => reason}
      end

      if Approvals.needs_approval?(self, mode: approval_mode, approved: approved)
        return {
          "status" => "approval_required",
          "tool" => name,
          "params" => params,
          "summary" => description
        }
      end

      callable.call(params, user)
    end

    def schema_error(params)
      params = (params || {}).to_h.transform_keys(&:to_s)
      schema = params_schema || {}
      missing = Array(schema[:required]).find { |key| missing_param?(params[key.to_s]) }
      return "#{missing} is required" if missing

      (schema[:properties] || {}).each do |key, property|
        minimum = property[:minProperties]
        value = params[key.to_s]
        next if minimum.nil? || value.nil?
        next if value.is_a?(Hash) && value.size >= minimum

        reason = "#{key} needs at least #{minimum} field"
        return property[:description] ? "#{reason}: #{property[:description]}" : reason
      end
      nil
    end

    private

    # Absent, not empty: an empty object is reported against its minProperties.
    def missing_param?(value)
      value.nil? || (value.is_a?(String) && value.strip.empty?)
    end
  end

  def self.tool_name(controller, operation)
    "#{controller}__#{operation}"
  end
end
