require "rails_helper"

RSpec.describe Product, type: :model do
  let(:attributes) { { name: "Baly", url: "https://example.com/baly" } }

  it "is valid with a name and a url" do
    expect(Product.new(attributes)).to be_valid
  end

  it "is invalid without a name" do
    expect(Product.new(attributes.except(:name))).not_to be_valid
  end

  it "is invalid without a url" do
    expect(Product.new(attributes.except(:url))).not_to be_valid
  end

  it "destroys its price checks when destroyed" do
    product = Product.create!(attributes)
    product.price_checks.create!(status: "ok", price_cents: 490, checked_at: Time.current)

    expect { product.destroy }.to change(PriceCheck, :count).by(-1)
  end
end
