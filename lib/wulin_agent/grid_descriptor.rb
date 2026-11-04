# frozen_string_literal: true

module WulinAgent
  GridDescriptor = Struct.new(
    :grid_class,
    :controller,
    :controller_class,
    :screen_name,
    :columns,
    :default_actions,
    :custom_actions
  )
end
