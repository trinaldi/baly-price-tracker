class CreatePriceChecks < ActiveRecord::Migration[8.0]
  def change
    create_table :price_checks do |t|
      t.integer :price_cents
      t.string :status
      t.text :error_message
      t.datetime :checked_at

      t.timestamps
    end
  end
end
