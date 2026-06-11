# frozen_string_literal: true

module PermissionsHelper
  def create_user_with_permissions(*permission_names, email: nil)
    user = User.create!(email: email || "user-#{SecureRandom.hex(4)}@example.com")
    privilege = Privilege.create!(name: "privilege-#{SecureRandom.hex(4)}")

    permission_names.each do |name|
      permission = Permission.find_or_create_by!(name: name)
      PermissionsPrivilege.find_or_create_by!(privilege: privilege, permission: permission)
    end

    UsersPrivilege.create!(user_id: user.id, privilege_id: privilege.id)
    user
  end
end

RSpec.configure do |config|
  config.include PermissionsHelper
end
