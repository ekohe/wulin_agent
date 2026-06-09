# frozen_string_literal: true

module WulinAgent
  GridDescriptor = Struct.new(
    :grid_class,
    :controller,
    :columns,
    :default_actions,
    :custom_actions,
    keyword_init: true
  )
end
