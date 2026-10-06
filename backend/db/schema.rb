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

ActiveRecord::Schema[8.1].define(version: 2026_02_01_000001) do
  create_table "comparisons", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "title", null: false
    t.json "items"
    t.text "result", null: false
    t.boolean "ai_generated", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_comparisons_on_user_id"
  end

  create_table "email_tokens", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "purpose", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_email_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_email_tokens_on_user_id"
  end

  create_table "saved_articles", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "title", null: false
    t.string "url", null: false
    t.string "source"
    t.text "description"
    t.string "meta"
    t.string "author"
    t.string "date"
    t.json "tags"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "url"], name: "index_saved_articles_on_user_id_and_url", unique: true
    t.index ["user_id"], name: "index_saved_articles_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "token_digest", null: false
    t.datetime "last_used_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["last_used_at"], name: "index_sessions_on_last_used_at"
    t.index ["token_digest"], name: "index_sessions_on_token_digest", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "trend_snapshots", force: :cascade do |t|
    t.string "tag", null: false
    t.float "score", null: false
    t.datetime "captured_at", null: false
    t.index ["captured_at"], name: "index_trend_snapshots_on_captured_at"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "email_verified_at"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "comparisons", "users"
  add_foreign_key "email_tokens", "users"
  add_foreign_key "saved_articles", "users"
  add_foreign_key "sessions", "users"
end
