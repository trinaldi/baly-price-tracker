class AddClubPriceCents < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :club_price_cents, :integer
    add_column :price_checks, :club_price_cents, :integer
  end
end
