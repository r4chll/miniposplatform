class CreatePaymentSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :payment_schedules do |t|
      t.references :loan_application, null: false, foreign_key: true
      t.integer :payment_number, null: false
      t.date :due_date, null: false
      t.decimal :principal_amount, precision: 12, scale: 2, null: false
      t.decimal :interest_amount, precision: 12, scale: 2, null: false
      t.decimal :total_amount, precision: 12, scale: 2, null: false
      t.decimal :remaining_balance, precision: 12, scale: 2, null: false

      t.timestamps
    end

    add_index :payment_schedules, [ :loan_application_id, :payment_number ], unique: true
  end
end
