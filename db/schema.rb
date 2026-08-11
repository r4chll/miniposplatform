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

ActiveRecord::Schema[8.0].define(version: 2026_08_11_120004) do
  create_table "customers", force: :cascade do |t|
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "email", null: false
    t.integer "credit_score", null: false
    t.decimal "annual_income", precision: 12, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_customers_on_email", unique: true
  end

  create_table "loan_applications", force: :cascade do |t|
    t.integer "merchant_id", null: false
    t.integer "customer_id", null: false
    t.decimal "purchase_amount", precision: 12, scale: 2, null: false
    t.integer "term_months", null: false
    t.string "status", default: "pending", null: false
    t.decimal "interest_rate", precision: 5, scale: 2
    t.string "denial_reason"
    t.datetime "decided_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_loan_applications_on_customer_id"
    t.index ["merchant_id"], name: "index_loan_applications_on_merchant_id"
    t.index ["status"], name: "index_loan_applications_on_status"
  end

  create_table "merchants", force: :cascade do |t|
    t.string "name", null: false
    t.string "industry", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["industry"], name: "index_merchants_on_industry"
  end

  create_table "payment_schedules", force: :cascade do |t|
    t.integer "loan_application_id", null: false
    t.integer "payment_number", null: false
    t.date "due_date", null: false
    t.decimal "principal_amount", precision: 12, scale: 2, null: false
    t.decimal "interest_amount", precision: 12, scale: 2, null: false
    t.decimal "total_amount", precision: 12, scale: 2, null: false
    t.decimal "remaining_balance", precision: 12, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["loan_application_id", "payment_number"], name: "idx_on_loan_application_id_payment_number_f44bb2735c", unique: true
    t.index ["loan_application_id"], name: "index_payment_schedules_on_loan_application_id"
  end

  add_foreign_key "loan_applications", "customers"
  add_foreign_key "loan_applications", "merchants"
  add_foreign_key "payment_schedules", "loan_applications"
end
