# frozen_string_literal: true

module WulinAgent
  class GridAccess
    class Error < StandardError; end

    def self.find_grid!(controller)
      grid = Catalog.find(controller.to_s)
      raise Error, "Unknown controller: #{controller}" unless grid
      grid
    end

    def self.authorized?(user, grid, operation)
      return true if user.respond_to?(:admin?) && user.admin?

      permission = permission_for(grid, operation)
      user.has_permission_with_name?(permission)
    end

    def self.authorize!(user, grid, operation)
      return if authorized?(user, grid, operation)
      raise Error, "Unauthorized for #{grid.controller}##{operation}"
    end

    def self.permission_for(grid, operation)
      case operation.to_s
      when "get_columns", "index", "read" then "#{grid.screen_name}#read"
      when "create", "update", "destroy"  then "#{grid.screen_name}#cud"
      else "#{grid.controller}##{operation}"
      end
    end

    def self.operation_available?(grid, operation)
      case operation.to_s
      when "create"  then grid.default_actions["create"]
      when "update"  then grid.default_actions["edit"]
      when "destroy" then grid.default_actions["delete"]
      else true
      end
    end

    def self.accessible_grids(user)
      Catalog.all.select { |grid| authorized?(user, grid, "index") }
    end
  end
end