require "rails_helper"

RSpec.describe PriceTracker::Markets::Defaults do
  let(:market) do
    Class.new do
      extend PriceTracker::Markets::Defaults

      def self.cookie = "a=b"
    end
  end

  it "fetches through the Fetcher with the market cookie" do
    allow(PriceTracker::Fetcher).to receive(:get).and_return("<html></html>")

    expect(market.fetch_html("https://x.test")).to eq("<html></html>")
    expect(PriceTracker::Fetcher).to have_received(:get)
      .with("https://x.test", headers: { "Cookie" => "a=b" })
  end

  it "is available by default" do
    expect(market.available?("<html></html>")).to be(true)
  end

  it "has no club price by default" do
    expect(market.club_price_cents("<html></html>")).to be_nil
  end
end
