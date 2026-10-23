require "rails_helper"

RSpec.describe PriceTracker::Runner do
  let(:market) do
    class_double(
      PriceTracker::Markets::Simao,
      host: "example.com",
      cookie: "test-cookie"
    ).as_stubbed_const
  end

  let(:product) do
    Product.create!(
      name: "Baly",
      slug: "baly",
      url: "https://example.com/baly"
    )
  end
  let(:parsed) { PriceTracker::Parser::Result.new(name: "Baly", price_cents: 490) }
  let(:delivery) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }


  before do
    allow(PriceTracker::Markets).to receive(:for).and_return(market)
    allow(market).to receive(:price_cents).and_return(490)
    allow(market).to receive(:club_price_cents).and_return(nil)
    allow(PriceTracker::Fetcher).to receive(:get).and_return("<html></html>")
    allow(PriceMailer).to receive(:price_changed).and_return(delivery)
    allow(PriceMailer).to receive(:failed).and_return(delivery)
    allow(PriceMailer).to receive(:club_offer).and_return(delivery)
  end

  context "when the market is unknown" do
    let(:product) { Product.create!(name: "X", slug: "x", url: "https://unknown.example.com/x") }

    before { allow(PriceTracker::Markets).to receive(:for).and_call_original }

    it "records an error check and emails" do
      check = described_class.call(product)

      expect(check.status).to eq("error")
      expect(PriceMailer).to have_received(:failed).with(product, a_string_including("unknown.example.com"))
    end
  end

  context "when the market is misconfigured" do
    let(:product) { Product.create!(name: "J", slug: "j", url: "https://www.jauserve.com.br/1.html") }

    before do
      allow(PriceTracker::Markets).to receive(:for).and_call_original
      allow(PriceTracker::Markets::Jauserve).to receive(:cookie)
        .and_raise(PriceTracker::Markets::ConfigError, "JAUSERVE_CEP is not set")
    end

    it "records an error check and emails" do
      check = described_class.call(product)

      expect(check.status).to eq("error")
      expect(PriceMailer).to have_received(:failed).with(product, "JAUSERVE_CEP is not set")
    end
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
      allow(market).to receive(:price_cents)
        .and_raise(PriceTracker::Markets::ParseError, "price element not found")
    end

    it "records an error check and emails" do
      check = described_class.call(product)

      expect(check.status).to eq("error")
      expect(PriceMailer).to have_received(:failed)
    end
  end

  context "with a club price" do
    let(:club_cents) { 399 }

    before { allow(market).to receive(:club_price_cents).and_return(club_cents) }

    context "on the first check" do
      it "stores both prices and does not email" do
        described_class.call(product)

        product.reload
        expect(product.price_cents).to eq(490)
        expect(product.club_price_cents).to eq(399)
        expect(PriceMailer).not_to have_received(:club_offer)
        expect(PriceMailer).not_to have_received(:price_changed)
      end
    end

    context "when the club offer appears" do
      before { product.update!(price_cents: 490, club_price_cents: nil) }

      it "emails the club offer" do
        described_class.call(product)

        expect(PriceMailer).to have_received(:club_offer).with(product, 399, 490)
        expect(PriceMailer).not_to have_received(:price_changed)
      end

      it "does not touch last_changed_at" do
        described_class.call(product)

        expect(product.reload.last_changed_at).to be_nil
      end
    end

    context "when the club price changes and is still cheaper" do
      before { product.update!(price_cents: 490, club_price_cents: 450) }

      it "emails the club offer" do
        described_class.call(product)

        expect(PriceMailer).to have_received(:club_offer).with(product, 399, 490)
      end
    end

    context "when the club price is unchanged" do
      before { product.update!(price_cents: 490, club_price_cents: 399) }

      it "does not email" do
        described_class.call(product)

        expect(PriceMailer).not_to have_received(:club_offer)
      end
    end

    context "when the club price is not cheaper than the regular price" do
      let(:club_cents) { 490 }

      before { product.update!(price_cents: 490, club_price_cents: nil) }

      it "does not email" do
        described_class.call(product)

        expect(PriceMailer).not_to have_received(:club_offer)
      end
    end
  end

  context "when the club offer ends" do
    before do
      product.update!(price_cents: 490, club_price_cents: 399)
      allow(market).to receive(:club_price_cents).and_return(nil)
    end

    it "clears the club price and does not email" do
      described_class.call(product)

      expect(product.reload.club_price_cents).to be_nil
      expect(PriceMailer).not_to have_received(:club_offer)
      expect(PriceMailer).not_to have_received(:price_changed)
    end
  end
end
