class PriceCheck < ApplicationRecord
  validates :price_cents, presence: true, if: -> { status == "ok" }
end
