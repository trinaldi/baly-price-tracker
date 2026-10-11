require "rails_helper"

RSpec.describe PriceTracker::Runner do
  let(:product) { Product.create!(name: "Baly", url: "https://example.com/baly") }
  let(:parsed)  { PriceTracker::Parser::Result.new(name: "Baly", price_cents: 490) }
  let(:delivery) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }

  before do
    allow(PriceTracker::Fetcher).to receive(:get).and_return("<html></html>")
    allow(PriceTracker::Parser).to receive(:parse).and_return(parsed)
    allow(PriceMailer).to receive(:price_changed).and_return(delivery)
    allow(PriceMailer).to receive(:failed).and_return(delivery)
  end

  context "when the product has no price yet (first check)" do
    it "saves an ok check" do
      check = described_class.call(product)

      expect(check).to be_persisted
      expect(check.status).to eq("ok")
      expect(check.price_cents).to eq(490)
    end

    it "stores the price on the product without marking a change" do
      described_class.call(product)

      product.reload
      expect(product.price_cents).to eq(490)
      expect(product.last_changed_at).to be_nil
    end

    it "does not email" do
      described_class.call(product)

      expect(PriceMailer).not_to have_received(:price_changed)
    end
  end

  context "when the price is unchanged" do
    let!(:changed_at) { 1.day.ago }

    before { product.update!(price_cents: 490, last_changed_at: changed_at) }

    it "records a new check" do
      expect { described_class.call(product) }.to change(PriceCheck, :count).by(1)
    end

    it "does not email" do
      described_class.call(product)

      expect(PriceMailer).not_to have_received(:price_changed)
    end

    it "keeps last_changed_at" do
      described_class.call(product)

      expect(product.reload.last_changed_at).to be_within(1.second).of(changed_at)
    end
  end

  context "when the price changed" do
    before { product.update!(price_cents: 450) }

    it "emails with the old and the new price" do
      described_class.call(product)

      expect(PriceMailer).to have_received(:price_changed).with(product, 450, 490)
    end

    it "updates the price and last_changed_at on the product" do
      described_class.call(product)

      product.reload
      expect(product.price_cents).to eq(490)
      expect(product.last_changed_at).to be_within(5.seconds).of(Time.current)
    end
  end

  context "when the fetch fails" do
    before do
      product.update!(price_cents: 450)
      allow(PriceTracker::Fetcher).to receive(:get)
        .and_raise(PriceTracker::Fetcher::FetchError, "boom")
    end

    it "records an error check and emails" do
      check = described_class.call(product)

      expect(check.status).to eq("error")
      expect(check.error_message).to eq("boom")
      expect(PriceMailer).to have_received(:failed).with(product, "boom")
    end

    it "keeps the product price untouched" do
      described_class.call(product)

      expect(product.reload.price_cents).to eq(450)
    end
  end

  context "when the parse fails" do
    before do
      allow(PriceTracker::Parser).to receive(:parse)
        .and_raise(PriceTracker::Parser::ParseError, "price element not found")
    end

    it "records an error check and emails" do
      check = described_class.call(product)

      expect(check.status).to eq("error")
      expect(PriceMailer).to have_received(:failed)
    end
  end
end
