class CreateMerchants < ActiveRecord::Migration[8.0]
  def change
    create_table :merchants do |t|
      t.string :name, null: false
      t.string :industry, null: false

      t.timestamps
    end

    add_index :merchants, :industry
  end
end
