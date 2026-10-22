# frozen_string_literal: true

module WulinAgent
  module GridListResponse
    DEBUG_KEYS = %w[sql query last_sql explain].freeze

    module_function

    def sanitize_metadata(payload, debug: false)
      return payload unless payload.is_a?(Hash)
      return payload if debug

      payload.except(*DEBUG_KEYS)
    end
  end
end
