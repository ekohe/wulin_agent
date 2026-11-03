# frozen_string_literal: true

module WulinAgent
  module ColumnMetadata
    BELONGS_TO = "belongs_to"
    COMPUTED_COLUMN_HINT = "Computed column — not filterable or sortable via list_records."
    NUMERIC_RANGE_HINT =
      "Numeric range: use gte, lte, gt, lt, or between (value_from / value_to) in list_records filters."
    DATE_RANGE_HINT =
      "Date/datetime range filters are not supported; use sort_col and pagination."

    module_function

    def serialize(column, model: nil)
      filterable = agent_filterable?(column, model: model)
      sortable = agent_sortable?(column, model: model)

      payload = {
        name: column.name.to_s,
        label: column.label,
        sql_type: column.sql_type.to_s,
        filterable: filterable,
        sortable: sortable,
        choices: column.choices
      }.compact

      if filterable
        hint = filter_value_hint(column, model: model)
        payload[:value_hint] = hint if hint.present?
      end
      payload[:value_hint] = COMPUTED_COLUMN_HINT if computed_column?(column, model: model)

      return payload unless column.sql_type.to_s == BELONGS_TO

      reflection = column_reflection(column, model: model)
      return payload unless reflection

      payload.merge(association_payload(column, reflection))
    end

    def agent_filterable?(column, model: nil)
      column.filterable && sql_queryable?(column, model: model)
    end

    def agent_sortable?(column, model: nil)
      column.sortable && sql_queryable?(column, model: model)
    end

    def sql_queryable?(column, model: nil)
      return true if column_options(column)[:sql_expression].present?
      return true if table_column?(column)
      return true if belongs_to_sql_column?(column, model: model)
      return true if reflected_sql_column?(column)
      return false if column.sql_type.to_s == "unknown"
      return true unless column.respond_to?(:table_column?)

      false
    end

    def computed_column?(column, model: nil)
      column.filterable && !sql_queryable?(column, model: model)
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

    def filter_value_hint(column, model: nil)
      sql_type = column.sql_type.to_s
      return NUMERIC_RANGE_HINT if %w[integer float decimal].include?(sql_type)
      return DATE_RANGE_HINT if %w[date datetime].include?(sql_type)

      nil
    end

    def build_value_hint(name, foreign_key, lookup_controller)
      "Foreign key, not a display string. " \
        "Pass #{foreign_key} (integer) or #{name}: {\"id\": N}. " \
        "Call list_records on \"#{lookup_controller}\" first to resolve IDs."
    end

    def belongs_to_sql_column?(column, model: nil)
      column.sql_type.to_s == BELONGS_TO && column_reflection(column, model: model).present?
    end

    def foreign_key_filter_value?(value)
      case value
      when Integer
        true
      when Hash
        value.key?("id") || value.key?(:id)
      when String
        value.strip.match?(/\A\d+\z/)
      when Numeric
        true
      else
        false
      end
    end

    def foreign_key_filter_error(column, model: nil)
      reflection = column_reflection(column, model: model)
      name = column.name.to_s
      lookup_controller =
        if reflection
          ModelNaming.for(reflection.klass).plural
        else
          "the associated records"
        end

      "Column \"#{name}\" expects a numeric id (or {\"id\": N}), not a display name. " \
        "Resolve ids via list_records on \"#{lookup_controller}\"."
    end

    def reflected_sql_column?(column)
      reflection = column_reflection(column)
      return false unless reflection
      return false unless reflection.klass < ActiveRecord::Base

      reflection.klass.column_names.include?(column_source(column).to_s)
    end

    def table_column?(column)
      column.respond_to?(:table_column?) && column.table_column?
    end

    def column_reflection(column, model: nil)
      if column.respond_to?(:reflection) && column.reflection
        column.reflection
      elsif model&.respond_to?(:reflect_on_association)
        model.reflect_on_association(column.name)
      end
    end

    def column_source(column)
      column.respond_to?(:source) ? column.source : column.name
    end

    def column_options(column)
      column.respond_to?(:options) ? column.options : {}
    end
  end
end
