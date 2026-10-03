require "rails_helper"

RSpec.describe PriceCheck, type: :model do
  let(:product) { Product.create!(name: "Baly", url: "https://example.com/baly") }

  it "is invalid with status ok and no price_cents" do
    check = PriceCheck.new(product: product, status: "ok", price_cents: nil)

    expect(check).not_to be_valid
    expect(check.errors[:price_cents]).to be_present
  end

  it "is valid with status ok and a price" do
    check = PriceCheck.new(product: product, status: "ok", price_cents: 490)

    expect(check).to be_valid
  end

  it "is valid with status error and no price" do
    check = PriceCheck.new(product: product, status: "error", error_message: "boom")

    expect(check).to be_valid
  end

  it "is invalid without a product" do
    check = PriceCheck.new(status: "ok", price_cents: 490)

    expect(check).not_to be_valid
  end
end
