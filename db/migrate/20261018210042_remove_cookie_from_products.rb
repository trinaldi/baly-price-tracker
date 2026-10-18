class RemoveCookieFromProducts < ActiveRecord::Migration[8.1]
  def change
    remove_column :products, :cookie, :string
  end
end
