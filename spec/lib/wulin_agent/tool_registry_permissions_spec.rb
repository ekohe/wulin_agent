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

    it "returns all meta tools for an admin user" do
      admin = User.create!(email: "admin@example.com", admin: true)
      names = described_class.for(admin).map(&:name)

      expect(names).to include(
        "list_grids",
        "get_columns",
        "list_records",
        "read_record",
        "create_record",
        "update_record",
        "destroy_record"
      )
    end

    it "returns read-only meta tools for a user with person#read" do
      reader = create_user_with_permissions("person#read")
      names = described_class.for(reader).map(&:name)

      expect(names).to include("list_grids", "get_columns", "list_records", "read_record")
      expect(names).not_to include("create_record", "update_record", "destroy_record")
    end

    it "returns mutating meta tools for a user with person#cud" do
      editor = create_user_with_permissions("person#cud")
      names = described_class.for(editor).map(&:name)

      expect(names).to include("create_record", "update_record", "destroy_record")
      expect(names).not_to include("list_records", "read_record", "get_columns")
    end
  end
end
