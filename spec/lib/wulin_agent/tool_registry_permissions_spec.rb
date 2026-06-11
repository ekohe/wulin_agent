# frozen_string_literal: true

require "rails_helper"
require "wulin_agent/tool_registry"

RSpec.describe WulinAgent::ToolRegistry, "permissions" do
  before do
    WulinAgent::Catalog.reset!
    described_class.reset!
    PersonScreen
    PersonGrid
    Permission.find_or_create_by!(name: "person#read")
    Permission.find_or_create_by!(name: "person#cud")
  end

  describe ".for" do
    it "returns no tools when user is nil" do
      expect(described_class.for(nil)).to eq([])
    end

    it "returns all tools for an admin user" do
      admin = User.create!(email: "admin@example.com", admin: true)
      names = described_class.for(admin).map(&:name)

      expect(names).to include(
        "people__get_columns",
        "people__index",
        "people__read",
        "people__create",
        "people__update",
        "people__destroy"
      )
    end

    it "returns read-only tools for a user with person#read" do
      reader = create_user_with_permissions("person#read")
      names = described_class.for(reader).map(&:name)

      expect(names).to include("people__get_columns", "people__index", "people__read")
      expect(names).not_to include("people__create", "people__update", "people__destroy")
    end

    it "returns mutating tools for a user with person#cud" do
      editor = create_user_with_permissions("person#cud")
      names = described_class.for(editor).map(&:name)

      expect(names).to include("people__create", "people__update", "people__destroy")
      expect(names).not_to include("people__index", "people__read", "people__get_columns")
    end
  end
end
