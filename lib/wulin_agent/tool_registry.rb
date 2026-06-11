# frozen_string_literal: true

module WulinAgent
  class ToolRegistry
    class << self
      def for(user = nil)
        @all ||= Catalog.all.flat_map do |grid|
          StandardGridTools.build(grid) + ActionInferer.build(grid)
        end
        filter_for_user(@all, user)
      end

      def find(name, user = nil)
        self.for(user).find { |tool| tool.name == name }
      end

      def reset!
        @all = nil
      end

      private

      def filter_for_user(tools, user)
        return [] if user.nil?
        return tools if user.respond_to?(:admin?) && user.admin?

        if user.respond_to?(:has_permission_with_name?)
          tools.select { |tool| user.has_permission_with_name?(tool.permission) }
        elsif permits_available?
          allowed = UserAllPermission.where(user_id: user.id).pluck(:permission_name)
          tools.select { |tool| allowed.include?(tool.permission) }
        else
          []
        end
      end

      def permits_available?
        defined?(UserAllPermission) &&
          UserAllPermission.connection.data_source_exists?("user_all_permissions")
      end
    end
  end
end
