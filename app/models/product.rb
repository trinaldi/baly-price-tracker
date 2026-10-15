class Product < ApplicationRecord
  has_many :price_checks, dependent: :destroy

  validates :name, :url, presence: true
  validates :slug, presence: true, uniqueness: true
end
