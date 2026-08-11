class CreateCustomers < ActiveRecord::Migration[8.0]
  def change
    create_table :customers do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.integer :credit_score, null: false
      t.decimal :annual_income, precision: 12, scale: 2, null: false

      t.timestamps
    end

    add_index :customers, :email, unique: true
  end
end
