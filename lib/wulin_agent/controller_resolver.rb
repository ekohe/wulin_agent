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

        return grid_class.controller_class if grid_class.controller_class

        controller = controller_by_route(grid_class)
        return controller if controller

        controller_by_plural(grid_class)
      end

      def for_name(name)
        Catalog.find(name)&.controller_class
      end

      private

      def controller_by_route(grid_class)
        return nil unless defined?(Rails) && Rails.application

        path = normalize_path(grid_class.path)
        return nil if path == "/"

        recognized = Rails.application.routes.recognize_path(
          "#{path}.json",
          method: :GET
        )
        controller_class_for_path(recognized[:controller])
      rescue ActionController::RoutingError, NameError
        nil
      end

      def controller_by_plural(grid_class)
        plural = ModelNaming.for(grid_class.model).plural
        WulinMaster::ScreenController.descendants.find do |controller|
          controller.controller_name == plural
        end
      end

      def controller_class_for_path(controller_path)
        segments = controller_path.split("/")
        class_name = if segments.size == 1
          "#{segments.first.camelize}Controller"
        else
          namespace = segments[0..-2].map(&:camelize).join("::")
          "#{namespace}::#{segments.last.camelize}Controller"
        end

        class_name.constantize
      end

      def normalize_path(path)
        normalized = path.to_s.split("?", 2).first.chomp("/")
        normalized.empty? ? "/" : normalized
      end
    end
  end
end
