# frozen_string_literal: true

module WulinAgent
  class ToolRegistry
    class << self
      def for(user = nil)
        @all ||= Catalog.all.flat_map { |grid| StandardGridTools.build(grid) }
        filter_for_user(@all, user)
      end

      def find(name, user = nil)
        self.for(user).find { |tool| tool.name == name }
      end

      def reset!
        @all = nil
      end

      private

      def filter_for_user(tools, _user)
        tools
      end
    end
  end
end
