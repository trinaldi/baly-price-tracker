require "rails_helper"

RSpec.describe PriceTracker::Markets::TendaAtacado do
  let(:html) { file_fixture("tenda_atacado_product.html").binread }

  def available_page(price)
    %(<div class="ButtonBuyComponent"><button>Comprar</button></div>
      <span class="SimplePriceComponent">#{price}</span>)
  end

  let(:unavailable_page) { %(<div class="ProductNotAvailableComponent">Produto indisponível</div>) }

  it "has the site host" do
    expect(described_class.host).to eq("www.tendaatacado.com.br")
  end

  it "sends no cookie" do
    expect(described_class.cookie).to be_nil
  end

  it "has no club price" do
    expect(described_class.club_price_cents("<html></html>")).to be_nil
  end

  describe ".available?" do
    it "is true on the real page" do
      expect(described_class.available?(html)).to be(true)
    end

    it "is true when the buy component is present" do
      expect(described_class.available?(available_page("R$ 39,99 un"))).to be(true)
    end

    it "is false when the not available component is present" do
      expect(described_class.available?(unavailable_page)).to be(false)
    end

    it "is false when both markers are present" do
      expect(described_class.available?(available_page("R$ 39,99 un") + unavailable_page)).to be(false)
    end

    it "raises ParseError when neither marker is present" do
      expect { described_class.available?("<html></html>") }
        .to raise_error(PriceTracker::Markets::ParseError)
    end
  end

  describe ".price_cents" do
    it "reads the price from the real page" do
      expect(described_class.price_cents(html)).to eq(3999)
    end

    it "reads a price followed by the unit" do
      expect(described_class.price_cents(available_page("R$ 39,99 un"))).to eq(3999)
    end

    it "handles thousands separators" do
      expect(described_class.price_cents(available_page("R$ 1.299,90 un"))).to eq(129_990)
    end

    it "raises ParseError when the price element is missing" do
      expect { described_class.price_cents("<html></html>") }
        .to raise_error(PriceTracker::Markets::ParseError)
    end

    it "raises ParseError when the text has no price" do
      expect { described_class.price_cents(available_page("Consulte")) }
        .to raise_error(PriceTracker::Markets::ParseError)
    end
  end
end
