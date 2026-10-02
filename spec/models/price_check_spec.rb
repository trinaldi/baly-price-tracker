require 'rails_helper'

RSpec.describe PriceCheck, type: :model do
  it 'is invalid when status ok and no price' do
    check = PriceCheck.new(status: "ok", price_cents: nil)

    expect(check).not_to be_valid
    expect(check.errors[:price_cents]).to be_present
  end

  it 'is valid with status ok and a price' do
    check = PriceCheck.new(status: "ok", price_cents: 490)

    expect(check).to be_valid
  end
end
