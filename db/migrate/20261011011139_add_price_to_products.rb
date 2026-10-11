class AddPriceToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :price_cents, :integer
    add_column :products, :last_changed_at, :datetime
  end
end
