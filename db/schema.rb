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

ActiveRecord::Schema[7.1].define(version: 2025_09_22_162032) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "vector"

  create_table "llm_partial_responses", force: :cascade do |t|
    t.bigint "video_audit_id", null: false
    t.integer "chunk_index"
    t.jsonb "result"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["video_audit_id"], name: "index_llm_partial_responses_on_video_audit_id"
  end

# Could not dump table "ux_knowledge_documents" because of following StandardError
#   Unknown type 'vector(1536)' for column 'embedding'

  create_table "video_audits", force: :cascade do |t|
    t.string "video"
    t.string "status", default: "pending"
    t.jsonb "llm_response", default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "frames", default: [], array: true
    t.integer "score"
    t.string "processing_stage", default: "uploaded"
  end

  create_table "video_audits_backup", id: false, force: :cascade do |t|
    t.bigint "id"
    t.string "video"
    t.string "status"
    t.text "llm_response"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "frames", array: true
    t.integer "score"
  end

  add_foreign_key "llm_partial_responses", "video_audits"
end
