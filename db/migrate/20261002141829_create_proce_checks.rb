class CreateProceChecks < ActiveRecord::Migration[8.0]
  def change
    create_table :proce_checks do |t|
      t.integer :price_cents
      t.string :status
      t.string :error_message_text
      t.datetime :checked_at

      t.timestamps
    end
  end
end
