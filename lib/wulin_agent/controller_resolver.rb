# frozen_string_literal: true

module WulinAgent
  class ControllerResolver
    class << self
      def reset!
        @screen_controllers_loaded = false
      end

      def load_screen_controllers!
        return if @screen_controllers_loaded
        return unless defined?(Rails) && Rails.application

        controllers_path = Rails.root.join("app/controllers")
        if controllers_path.directory?
          Dir[controllers_path.join("**", "*_controller.rb")].sort.each do |file|
            relative = Pathname.new(file).relative_path_from(controllers_path).to_s
            relative.sub(/\.rb\z/, "").camelize.constantize
          rescue NameError
            nil
          end
        end

        @screen_controllers_loaded = true
      end

      def for_grid(grid_class)
        load_screen_controllers!

        controller = controller_for_grid(grid_class)
        return controller if controller

        constantize_with_namespace(grid_class.model.model_name.plural)
      end

      def for_name(name)
        grid = Catalog.find(name)
        return grid.controller_class if grid&.controller_class

        constantize_with_namespace(name)
      end

      private

      def controller_for_grid(grid_class)
        screens = screens_for_grid(grid_class)
        return nil if screens.empty?

        grid_path = normalize_path(grid_class.path)
        matches = screens.filter_map do |screen|
          controller = controller_for_screen(screen)
          next unless controller

          [screen, controller, normalize_path(screen.path) == grid_path]
        end

        return nil if matches.empty?

        path_match = matches.find { |_, _, path_matches| path_matches }
        path_match ? path_match[1] : matches.first[1]
      end

      def screens_for_grid(grid_class)
        Array(WulinMaster::Screen.screens).select do |screen|
          (screen.components_pool || []).include?(grid_class)
        end
      end

      def controller_for_screen(screen_class)
        WulinMaster::ScreenController.descendants.find do |controller|
          Array(controller.screen_classes).include?(screen_class)
        end
      end

      def normalize_path(path)
        normalized = path.to_s.split("?", 2).first.chomp("/")
        normalized.empty? ? "/" : normalized
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
