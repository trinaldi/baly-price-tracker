require "rails_helper"

RSpec.describe PriceTracker::Runner do
  let(:product) { Product.create!(name: "Baly energetico melancia zero açucar 473ML", url: "https://www.simaodoces.com.br/mercearia-/baly-energetico-melancia-zero-acucar-473ml") }
  let(:parsed) { PriceTracker::Parser::Result.new(name: "Baly energetico melancia zero açucar 473ML", price_cents: 490) }
  let(:delivery) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }

  before do
    allow(PriceTracker::Fetcher).to receive(:get).and_return("<html></html>")
    allow(PriceTracker::Parser).to receive(:parse).and_return(parsed)
    allow(PriceMailer).to receive(:price_changed).and_return(delivery)
    allow(PriceMailer).to receive(:failed).and_return(delivery)
  end

  it "saves an 'ok' check" do
    check = described_class.call(product)

    expect(check).to be_persisted
    expect(check.status).to eq("ok")
    expect(check.price_cents).to eq(490)
  end

  it "does not email on the first check" do
    described_class.call(product)

    expect(PriceMailer).not_to have_received(:price_changed)
  end

  it "does not email when the price is unchanged" do
    product.price_checks.create!(status: "ok", price_cents: 490, checked_at: 1.day.ago)

    described_class.call(product)

    expect(PriceMailer).not_to have_received(:price_changed)
  end

  it "emails when the price changed" do
    product.price_checks.create!(status: "ok", price_cents: 450, checked_at: 1.day.ago)

    described_class.call(product)

    expect(PriceMailer).to have_received(:price_changed).with(product, 450, 490)
  end

  it "records an error and emails when the fetch fails" do
    allow(PriceTracker::Fetcher).to receive(:get)
      .and_raise(PriceTracker::Fetcher::FetchError, "boom")

    check = described_class.call(product)

    expect(check.status).to eq("error")
    expect(check.error_message).to eq("boom")
    expect(PriceMailer).to have_received(:failed).with(product, "boom")
  end

  it "records an error and emails when parse fails" do
    allow(PriceTracker::Parser).to receive(:parse)
      .and_raise(PriceTracker::Parser::ParseError, "price element not found")

    check = described_class.call(product)

    expect(check.status).to eq("error")
    expect(PriceMailer).to have_received(:failed)
  end
end
