class AddProductToPriceChecks < ActiveRecord::Migration[8.0]
  def change
    add_reference :price_checks, :product, null: false, foreign_key: true
  end
end
