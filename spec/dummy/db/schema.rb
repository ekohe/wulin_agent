# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_11_150000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "grid_states", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.boolean "current", default: false, null: false
    t.string "grid_name"
    t.string "name", default: "default"
    t.text "state_value"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
    t.index ["user_id"], name: "index_grid_states_on_user_id"
  end

  create_table "people", id: :serial, force: :cascade do |t|
    t.integer "age", default: 18
    t.datetime "birthdate", precision: nil
    t.integer "country_id"
    t.datetime "created_at", precision: nil, null: false
    t.string "first_name"
    t.string "job"
    t.string "last_name"
    t.text "signature"
    t.integer "status", default: 0
    t.integer "training_id"
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "vip", default: false
    t.index ["country_id"], name: "index_people_on_country_id"
    t.index ["training_id"], name: "index_people_on_training_id"
  end

  create_table "permissions", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "description"
    t.string "name"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["name"], name: "uniq_permissions_name", unique: true
  end

  create_table "permissions_privileges", force: :cascade do |t|
    t.integer "permission_id"
    t.integer "privilege_id"
  end

  create_table "permissions_roles", id: :serial, force: :cascade do |t|
    t.integer "permission_id"
    t.integer "role_id"
  end

  create_table "privileges", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "description"
    t.string "name"
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "roles", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.text "description"
    t.string "name"
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "roles_privileges", force: :cascade do |t|
    t.integer "privilege_id"
    t.integer "role_id"
  end

  create_table "roles_users", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.integer "role_id"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "users_privileges", force: :cascade do |t|
    t.integer "privilege_id"
    t.integer "user_id"
  end
end
