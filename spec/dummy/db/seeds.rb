# frozen_string_literal: true

admin = User.find_or_create_by!(email: "admin@example.com")
admin.update!(admin: true) unless admin.admin?

Person.find_or_create_by!(first_name: "Alice", last_name: "Martin")
Person.find_or_create_by!(first_name: "Bob", last_name: "Smith")
