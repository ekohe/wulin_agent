# frozen_string_literal: true

module WulinAgent
  class ToolRegistry
    class << self
      def for(user = nil)
        return [] if user.nil?

        meta = MetaGridTools.build + KnowledgeTools.build + SkillTools.build +
               ChartTools.build

        filter_meta_tools(meta, user) + filter_custom_tools(custom_tools, user)
      end

      def find(name, user = nil)
        self.for(user).find { |tool| tool.name == name }
      end

      def reset!
        @custom_tools = nil
      end

      private

      def custom_tools
        @custom_tools ||= Catalog.all.flat_map { |grid| ActionInferer.build(grid) }
                                     .uniq(&:name)
      end

      def filter_meta_tools(tools, user)
        return tools if user.respond_to?(:admin?) && user.admin?

        can_read = GridAccess.accessible_grids(user).any?
        can_write = Catalog.all.any? { |grid| GridAccess.authorized?(user, grid, "create") }

        tools.select do |tool|
          next true if meta_read_tool?(tool)

          if tool.name == "list_grids"
            can_read || can_write
          elsif tool.mutating
            can_write
          else
            can_read
          end
        end
      end

      def knowledge_tool?(tool)
        tool.name.start_with?("knowledge_")
      end

      def skill_tool?(tool)
        tool.name.start_with?("skill_")
      end

      def meta_read_tool?(tool)
        (knowledge_tool?(tool) || skill_tool?(tool)) && !tool.mutating
      end

      def filter_custom_tools(tools, user)
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
