require "rails_helper"

RSpec.describe PriceTracker::Markets do
  it "finds the market by the host of the url" do
    market = described_class.for("https://www.simaodoces.com.br/doces/qualquer-coisa")

    expect(market).to eq(PriceTracker::Markets::Simao)
  end

  it "finds the market by the host of the url jauserve" do
    market = described_class.for("https://www.jauserve.com.br/doces/qualquer-coisa")

    expect(market).to eq(PriceTracker::Markets::Jauserve)
  end

  it "raises for an unknown host" do
    expect { described_class.for("https://outro-site.example.com/x") }
      .to raise_error(PriceTracker::Markets::UnknownMarket)
  end
end
