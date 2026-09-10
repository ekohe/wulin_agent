# frozen_string_literal: true

module WulinAgent
  module ColumnMetadata
    BELONGS_TO = "belongs_to"

    module_function

    def serialize(column, model: nil)
      payload = {
        name: column.name.to_s,
        label: column.label,
        sql_type: column.sql_type.to_s,
        filterable: column.filterable,
        sortable: column.sortable,
        choices: column.choices
      }.compact

      return payload unless column.sql_type.to_s == BELONGS_TO

      reflection = column.reflection || model&.reflect_on_association(column.name)
      return payload unless reflection

      payload.merge(association_payload(column, reflection))
    end

    def association_payload(column, reflection)
      name = column.name.to_s
      foreign_key = reflection.foreign_key.to_s
      lookup_controller = ModelNaming.for(reflection.klass).plural
      {
        foreign_key: foreign_key,
        lookup_controller: lookup_controller,
        value_hint: build_value_hint(name, foreign_key, lookup_controller)
      }
    end

    def build_value_hint(name, foreign_key, lookup_controller)
      "Foreign key, not a display string. " \
        "Pass #{foreign_key} (integer) or #{name}: {\"id\": N}. " \
        "Call list_records on \"#{lookup_controller}\" first to resolve IDs."
    end
  end
end