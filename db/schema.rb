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

ActiveRecord::Schema[7.1].define(version: 2025_10_23_101841) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "vector"

  create_table "issue_screenshots", force: :cascade do |t|
    t.bigint "video_audit_id", null: false
    t.integer "issue_index"
    t.text "image_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "frame_sequence", default: 0
    t.integer "frame_number"
    t.boolean "is_primary", default: false
    t.index ["video_audit_id", "issue_index", "frame_sequence"], name: "index_screenshots_on_audit_issue_sequence"
    t.index ["video_audit_id"], name: "index_issue_screenshots_on_video_audit_id"
  end

  create_table "knowledge_base_categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.text "use_case"
    t.boolean "default_enabled", default: false
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_knowledge_base_categories_on_position"
    t.index ["slug"], name: "index_knowledge_base_categories_on_slug", unique: true
  end

  create_table "llm_partial_responses", force: :cascade do |t|
    t.bigint "video_audit_id", null: false
    t.integer "chunk_index"
    t.jsonb "result"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["video_audit_id"], name: "index_llm_partial_responses_on_video_audit_id"
  end

  create_table "user_knowledge_preferences", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "knowledge_base_category_id", null: false
    t.boolean "enabled", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["enabled"], name: "index_user_knowledge_preferences_on_enabled", where: "(enabled = true)"
    t.index ["knowledge_base_category_id"], name: "index_user_knowledge_preferences_on_knowledge_base_category_id"
    t.index ["user_id", "knowledge_base_category_id"], name: "index_user_knowledge_prefs_on_user_and_category", unique: true
    t.index ["user_id"], name: "index_user_knowledge_preferences_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

# Could not dump table "ux_knowledge_documents" because of following StandardError
#   Unknown type 'vector(1536)' for column 'embedding'

  create_table "video_audits", force: :cascade do |t|
    t.string "video"
    t.string "status", default: "pending"
    t.text "llm_response"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "frames", default: [], array: true
    t.integer "score"
    t.string "processing_stage", default: "uploaded"
    t.integer "issue_id_counter", default: 0
    t.string "jira_epic_key"
    t.string "share_token"
    t.datetime "shared_at"
    t.bigint "user_id", null: false
    t.text "thumbnail_image"
    t.boolean "completion_tracked", default: false, null: false
    t.string "title"
    t.text "description"
    t.index ["jira_epic_key"], name: "index_video_audits_on_jira_epic_key"
    t.index ["share_token"], name: "index_video_audits_on_share_token", unique: true
    t.index ["user_id"], name: "index_video_audits_on_user_id"
  end

  add_foreign_key "issue_screenshots", "video_audits"
  add_foreign_key "llm_partial_responses", "video_audits"
  add_foreign_key "user_knowledge_preferences", "knowledge_base_categories", on_delete: :cascade
  add_foreign_key "user_knowledge_preferences", "users", on_delete: :cascade
  add_foreign_key "ux_knowledge_documents", "knowledge_base_categories", column: "category_id"
  add_foreign_key "video_audits", "users"
end
