require "rails_helper"

RSpec.describe PriceTracker::Markets::Jauserve do
  def html_with(sales:, list: nil)
    strike = list ? %(<span class="strike-through list"><span class="value" content="#{list}"></span></span>) : ""
    %(<span class="price-content">#{strike}<span class="sales mr-2"><span class="value" content="#{sales}">R$</span></span></span>)
  end

  it "has the site host" do
    expect(described_class.host).to eq("www.jauserve.com.br")
  end

  it "builds the store and postal code cookie" do
    expect(described_class.cookie(cep: "00000-000"))
      .to eq("dw_storeid=3; dw_shippostalcode=00000-000")
  end

  it "reads the sales price in cents" do
    expect(described_class.price_cents(html_with(sales: "3.99"))).to eq(399)
  end

  it "handles a single decimal place" do
    expect(described_class.price_cents(html_with(sales: "4.9"))).to eq(490)
  end

  it "ignores the strike-through list price" do
    expect(described_class.price_cents(html_with(sales: "3.49", list: "3.99"))).to eq(349)
  end

  it "raises ParseError when there is no price" do
    expect { described_class.price_cents("<html></html>") }
      .to raise_error(PriceTracker::Markets::ParseError)
  end

  it "raises ParseError when the value is not a number" do
    expect { described_class.price_cents(html_with(sales: "abc")) }
      .to raise_error(PriceTracker::Markets::ParseError)
  end

  it "has no club price" do
    expect(described_class.club_price_cents("<html></html>")).to be_nil
  end
end
