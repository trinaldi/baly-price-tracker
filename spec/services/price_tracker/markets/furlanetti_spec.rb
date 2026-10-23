require "rails_helper"

RSpec.describe PriceTracker::Markets::Furlanetti do
  let(:html) { file_fixture("furlanetti_club_product.html").binread }

  let(:page_without_club) do
    %(<div data-testid="detail-info">
        <h1>Café Torrado em Grãos Espresso Café Pelé Pacote 1kg</h1>
        <div data-testid="price-display">
          <p data-testid="price-display-price">R$&nbsp;79,98</p>
        </div>
      </div>)
  end

  def page(regular:, offer: nil)
    panel = offer && %(
      <div data-testid="offer-panel">
        <div data-testid="offer-panel-header"><p>#{offer}</p></div>
        <div data-testid="offer-panel-footnote"><p>Limitado a 24 unidades promocionais por CPF.</p></div>
      </div>)

    %(<div data-testid="price-display"><p data-testid="price-display-price">#{regular}</p></div>#{panel})
  end

  it "has the site host" do
    expect(described_class.host).to eq("furlanetti.com.br")
  end

  describe ".price_cents" do
    it "reads the regular price from the real page, ignoring the club price" do
      expect(described_class.price_cents(html)).to eq(3099)
    end

    it "reads the regular price when the product has no club offer" do
      expect(described_class.price_cents(page_without_club)).to eq(7998)
    end

    it "handles thousands separators" do
      expect(described_class.price_cents(page(regular: "R$ 1.299,90"))).to eq(129_990)
    end

    it "raises ParseError when the price element is missing" do
      expect { described_class.price_cents("<html></html>") }
        .to raise_error(PriceTracker::Markets::ParseError)
    end

    it "raises ParseError when the text has no price" do
      expect { described_class.price_cents(page(regular: "Esgotado")) }
        .to raise_error(PriceTracker::Markets::ParseError)
    end
  end

  describe ".club_price_cents" do
    it "reads the club price from the real page" do
      expect(described_class.club_price_cents(html)).to eq(2699)
    end

    it "ignores numbers in the footnote" do
      page = page(regular: "R$ 1,95", offer: "R$&nbsp;1,49 para membros do Promoções do Clube")

      expect(described_class.club_price_cents(page)).to eq(149)
    end

    it "is nil when the product has no club offer" do
      expect(described_class.club_price_cents(page_without_club)).to be_nil
    end

    it "ignores an offer that is not from the club" do
      page = page(regular: "R$ 1,95", offer: "Leve 3 e pague 2")

      expect(described_class.club_price_cents(page)).to be_nil
    end

    it "raises ParseError when the club offer has no readable price" do
      page = page(regular: "R$ 1,95", offer: "Preço especial para membros do Promoções do Clube")

      expect { described_class.club_price_cents(page) }
        .to raise_error(PriceTracker::Markets::ParseError)
    end
  end
end
