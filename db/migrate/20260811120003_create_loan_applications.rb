class CreateLoanApplications < ActiveRecord::Migration[8.0]
  def change
    create_table :loan_applications do |t|
      t.references :merchant, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.decimal :purchase_amount, precision: 12, scale: 2, null: false
      t.integer :term_months, null: false
      t.string :status, null: false, default: "pending"
      t.decimal :interest_rate, precision: 5, scale: 2
      t.string :denial_reason
      t.datetime :decided_at

      t.timestamps
    end

    add_index :loan_applications, :status
  end
end
