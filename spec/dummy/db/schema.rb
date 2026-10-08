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

ActiveRecord::Schema[8.1].define(version: 2026_10_08_065342) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "agent_api_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", precision: nil
    t.datetime "last_used_at", precision: nil
    t.string "name"
    t.datetime "revoked_at", precision: nil
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["token"], name: "index_agent_api_tokens_on_token", unique: true
    t.index ["user_id"], name: "index_agent_api_tokens_on_user_id"
  end

  create_table "agent_approval_grants", force: :cascade do |t|
    t.datetime "consumed_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "expires_at", precision: nil, null: false
    t.jsonb "params", default: {}, null: false
    t.string "token_digest", null: false
    t.string "tool", null: false
    t.string "tool_call_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["expires_at"], name: "index_agent_approval_grants_on_expires_at"
    t.index ["token_digest"], name: "index_agent_approval_grants_on_token_digest", unique: true
    t.index ["user_id"], name: "index_agent_approval_grants_on_user_id"
  end

  create_table "agent_conversations", force: :cascade do |t|
    t.string "approval_mode", default: "confirm_writes", null: false
    t.datetime "created_at", null: false
    t.datetime "running_started_at", precision: nil
    t.string "status", default: "idle", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["status"], name: "index_agent_conversations_on_status"
    t.index ["user_id", "updated_at"], name: "index_agent_conversations_on_user_id_and_updated_at"
    t.index ["user_id"], name: "index_agent_conversations_on_user_id"
  end

  create_table "agent_knowledge", force: :cascade do |t|
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "scope"
    t.datetime "updated_at", null: false
    t.text "value", null: false
    t.index "key, COALESCE(scope, ''::character varying)", name: "index_agent_knowledge_on_key_and_scope", unique: true
    t.index ["category"], name: "index_agent_knowledge_on_category"
    t.index ["scope"], name: "index_agent_knowledge_on_scope"
  end

  create_table "agent_messages", force: :cascade do |t|
    t.text "content"
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "rating"
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "created_at"], name: "index_agent_messages_on_conversation_id_and_created_at"
    t.index ["conversation_id"], name: "index_agent_messages_on_conversation_id"
  end

  create_table "agent_skills", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by"
    t.text "description", null: false
    t.text "instructions", null: false
    t.string "name", null: false
    t.jsonb "tool_sequence", default: [], null: false
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0, null: false
    t.index ["name"], name: "index_agent_skills_on_name", unique: true
  end

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

  create_table "user_preferences", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "name", null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id", null: false
    t.text "value"
    t.index ["user_id", "name"], name: "index_user_preferences_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_user_preferences_on_user_id"
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

  add_foreign_key "agent_api_tokens", "users"
  add_foreign_key "agent_conversations", "users"
  add_foreign_key "agent_messages", "agent_conversations", column: "conversation_id"
end
