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

ActiveRecord::Schema[8.1].define(version: 2025_12_21_203302) do
  create_table "habit_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "end_hour", precision: 3, scale: 1
    t.integer "habit_id", null: false
    t.date "logged_on", null: false
    t.text "notes"
    t.decimal "start_hour", precision: 3, scale: 1
    t.datetime "updated_at", null: false
    t.index ["habit_id", "logged_on"], name: "index_habit_logs_on_habit_id_and_logged_on"
    t.index ["habit_id"], name: "index_habit_logs_on_habit_id"
  end

  create_table "habits", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "color", default: "#FDE047", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "habit_logs", "habits"
end
