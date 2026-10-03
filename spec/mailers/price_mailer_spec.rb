require "rails_helper"

RSpec.describe PriceMailer do
  let(:product) { Product.create!(name: "Baly", url: "https://example.com/baly") }

  before { ENV["PRICE_ALERT_EMAIL"] = "me@example.com" }

  it "builds the price_changed email" do
    mail = described_class.price_changed(product, 450, 490)

    expect(mail.to).to eq(["me@example.com"])
    expect(mail.subject).to include("Baly")
    expect(mail.body.encoded).to include("R$ 4,50").and include("R$ 4,90")
  end

  it "builds the failed email" do
    mail = described_class.failed(product, "boom")

    expect(mail.to).to eq(["me@example.com"])
    expect(mail.body.encoded).to include("boom")
  end
end
