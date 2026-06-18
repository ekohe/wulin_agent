# frozen_string_literal: true

module WulinAgent
  class ControllerResolver
    class << self
      def for_grid(grid_class)
        screen_class = screen_for_grid(grid_class)

        if screen_class
          controller = controller_for_screen(screen_class)
          return controller if controller
        end

        constantize_with_namespace(grid_class.model.model_name.plural)
      end

      def for_name(name)
        grid = Catalog.find(name)
        return grid.controller_class if grid&.controller_class

        constantize_with_namespace(name)
      end

      private

      def screen_for_grid(grid_class)
        WulinMaster::Screen.screens&.find do |screen|
          (screen.components_pool || []).include?(grid_class)
        end
      end

      def controller_for_screen(screen_class)
        WulinMaster::ScreenController.descendants.find do |controller|
          Array(controller.screen_classes).include?(screen_class)
        end
      end

      def constantize_with_namespace(name)
        base = "#{name.camelize}Controller"
        candidates = []
        candidates << "#{WulinAgent.controller_namespace}::#{base}" if WulinAgent.controller_namespace.present?
        candidates << base

        candidates.each do |class_name|
          return class_name.constantize
        rescue NameError
          next
        end

        raise NameError, "uninitialized constant #{candidates.last}"
      end
    end
  end
end
