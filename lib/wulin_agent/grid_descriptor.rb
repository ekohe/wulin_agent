# frozen_string_literal: true

module WulinAgent
  GridDescriptor = Struct.new(
    :grid_class,
    :controller,
    :screen_name,
    :columns,
    :default_actions,
    :custom_actions,
    keyword_init: true
  )
end
