require "rails_helper"

RSpec.describe PriceTracker::Markets::Simao do
  let(:html) { file_fixture("baly_melancia_sem_acucar.html").binread }

  def page(price)
    %(<span id="variacaoPreco">#{price}</span>)
  end

  it "has the site host" do
    expect(described_class.host).to eq("www.simaodoces.com.br")
  end

  it "sends the store cookie" do
    expect(described_class.cookie).to eq("LOJA=1106817")
  end

  it "has no club price" do
    expect(described_class.club_price_cents("<html></html>")).to be_nil
  end

  describe ".price_cents" do
    it "reads the price in cents from the real page" do
      expect(described_class.price_cents(html)).to eq(490)
    end

    it "reads a price with thousands separators" do
      expect(described_class.price_cents(page("R$ 1.299,90"))).to eq(129_990)
    end

    it "raises ParseError when the price element is missing" do
      expect { described_class.price_cents("<html></html>") }
        .to raise_error(PriceTracker::Markets::ParseError)
    end

    it "raises ParseError when the text has no price" do
      expect { described_class.price_cents(page("Sem estoque")) }
        .to raise_error(PriceTracker::Markets::ParseError)
    end
  end
end
