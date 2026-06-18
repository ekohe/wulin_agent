# frozen_string_literal: true

module WulinAgent
  class Catalog
    DEFAULT_ACTIONS = %w[create edit delete].freeze
    INTERNAL_ACTIONS = %w[hotkey_create hotkey_delete].freeze

    class << self
      def all
        @all ||= WulinMaster::Grid.grids.map { |grid_class| build(grid_class) }
      end

      def find(controller)
        all.find { |grid| grid.controller == controller }
      end

      def reset!
        @all = nil
      end

      private

      def build(grid_class)
        default_actions, custom_actions = build_actions(grid_class)

        GridDescriptor.new(
          grid_class: grid_class,
          controller: grid_class.model.model_name.plural,
          controller_class: ControllerResolver.for_grid(grid_class),
          screen_name: screen_name_for(grid_class),
          columns: build_columns(grid_class),
          default_actions: default_actions,
          custom_actions: custom_actions
        )
      end

      def build_columns(grid_class)
        grid_class.columns_pool
          .reject { |column| column.name == :id }
          .map { |column| build_column(column) }
      end

      def build_column(column)
        ColumnDescriptor.new(
          name: column.name,
          label: column.label,
          sql_type: column.sql_type,
          full_name: column.full_name,
          editable: column.options[:editable],
          formable: column.options[:formable],
          choices: normalize_choices(column.options[:choices]),
          sortable: column.sortable?,
          filterable: column.filterable?,
          reflection: nil
        )
      end

      def build_actions(grid_class)
        pool = grid_class.actions_pool.reject do |action|
          INTERNAL_ACTIONS.include?(action[:name].to_s)
        end

        default_actions = DEFAULT_ACTIONS.index_with do |name|
          pool.any? { |action| action[:name].to_s == name }
        end

        custom_actions = pool
          .reject { |action| DEFAULT_ACTIONS.include?(action[:name].to_s) }
          .map { |action| action.except(:name).merge(name: action[:name]) }

        [default_actions, custom_actions]
      end

      def normalize_choices(choices)
        choices.is_a?(Array) ? choices : nil
      end

      def screen_name_for(grid_class)
        screen_class = WulinMaster::Screen.screens&.find do |klass|
          (klass.components_pool || []).include?(grid_class)
        end

        if screen_class
          WulinMaster::Utilities.get_screen_name(screen_class.name)
        else
          grid_class.model.model_name.singular
        end
      end
    end
  end
end
