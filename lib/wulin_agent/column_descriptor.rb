# frozen_string_literal: true

module WulinAgent
  ColumnDescriptor = Struct.new(
    :name,
    :label,
    :sql_type,
    :full_name,
    :editable,
    :formable,
    :choices,
    :sortable,
    :filterable,
    :reflection,
    keyword_init: true
  )
end
