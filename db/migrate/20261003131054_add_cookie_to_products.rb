class AddCookieToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :cookie, :string
  end
end
