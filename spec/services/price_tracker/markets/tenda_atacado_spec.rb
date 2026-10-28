require "rails_helper"

RSpec.describe PriceTracker::Markets::TendaAtacado do
  let(:available_html) do
    <<~HTML
      <html>
        <div class="ButtonBuyComponent">Adicionar</div>
        <div class="SimplePriceComponent">R$ 39,99</div>
      </html>
    HTML
  end

  let(:unavailable_html) do
    <<~HTML
      <html>
        <div class="ProductNotAvailableComponent">Produto indisponível</div>
        <div class="SimplePriceComponent">R$ 39,99</div>
      </html>
    HTML
  end

  describe ".host" do
    it "returns the Tenda Atacado host" do
      expect(described_class.host).to eq("www.tendaatacado.com.br")
    end
  end

  describe ".cookie" do
    it "returns nil" do
      expect(described_class.cookie).to be_nil
    end
  end

  describe ".club_price_cents" do
    it "returns nil" do
      expect(described_class.club_price_cents(available_html)).to be_nil
    end
  end

  describe ".available?" do
    it "returns true when the buy button is present" do
      expect(described_class.available?(available_html)).to be(true)
    end

    it "returns false when the product is unavailable" do
      expect(described_class.available?(unavailable_html)).to be(false)
    end

    it "prioritizes unavailability when both markers are present" do
      html = %(<div class="ButtonBuyComponent">Adicionar</div>
               <div class="ProductNotAvailableComponent">Indisponível</div>)

      expect(described_class.available?(html)).to be(false)
    end

    it "raises ParseError when availability markers are missing" do
      expect { described_class.available?("<html><body>Produto</body></html>") }
        .to raise_error(PriceTracker::Markets::ParseError)
    end
  end

  describe ".price_cents" do
    it "parses a Brazilian price into cents" do
      expect(described_class.price_cents(available_html)).to eq(3999)
    end

    it "parses a price followed by the unit" do
      html = '<div class="SimplePriceComponent">R$ 39,99 un</div>'

      expect(described_class.price_cents(html)).to eq(3999)
    end

    it "parses prices with thousands separators" do
      html = '<div class="SimplePriceComponent">R$ 1.234,56</div>'

      expect(described_class.price_cents(html)).to eq(123_456)
    end

    it "still reads the price of an unavailable product" do
      expect(described_class.price_cents(unavailable_html)).to eq(3999)
    end

    it "raises ParseError when the price element is missing" do
      expect { described_class.price_cents("<html><body>Produto</body></html>") }
        .to raise_error(PriceTracker::Markets::ParseError, "price element not found")
    end

    it "raises ParseError when the price is invalid" do
      html = '<div class="SimplePriceComponent">Consulte o preço</div>'

      expect { described_class.price_cents(html) }
        .to raise_error(PriceTracker::Markets::ParseError, /invalid price/)
    end
  end

  describe ".fetch_html" do
    let(:url) { "https://www.tendaatacado.com.br/produto/exemplo" }
    let(:browser) { double("Ferrum::Browser") }
    let(:page) { double("Ferrum::Page") }
    let(:clock) { { now: 0.0 } }

    before do
      allow(Ferrum::Browser).to receive(:new).and_return(browser)
      allow(browser).to receive(:create_page).and_return(page)
      allow(browser).to receive(:quit)
      allow(page).to receive(:go_to).with(url)
      allow(page).to receive_message_chain(:network, :wait_for_idle)

      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) { clock[:now] }
      allow(described_class).to receive(:sleep) { |duration| clock[:now] += duration }
    end

    it "waits for availability to stabilize before returning the HTML" do
      allow(page).to receive(:body) { clock[:now] < 0.6 ? available_html : unavailable_html }

      html = described_class.fetch_html(url)

      expect(described_class.available?(html)).to be(false)
    end

    it "keeps going when the network never gets idle" do
      allow(page).to receive_message_chain(:network, :wait_for_idle)
        .and_raise(Ferrum::TimeoutError)
      allow(page).to receive(:body).and_return(available_html)

      expect(described_class.available?(described_class.fetch_html(url))).to be(true)
    end

    it "raises ParseError when availability markers never appear" do
      allow(page).to receive(:body).and_return("<html></html>")

      expect { described_class.fetch_html(url) }
        .to raise_error(PriceTracker::Markets::ParseError, "availability markers did not stabilize")
    end

    it "raises FetchError when the browser fails" do
      allow(page).to receive(:go_to).and_raise(Ferrum::TimeoutError)

      expect { described_class.fetch_html(url) }
        .to raise_error(PriceTracker::Fetcher::FetchError, /Ferrum::TimeoutError/)
    end

    it "raises FetchError when the browser cannot be started" do
      allow(Ferrum::Browser).to receive(:new).and_raise(Ferrum::BinaryNotFoundError)

      expect { described_class.fetch_html(url) }
        .to raise_error(PriceTracker::Fetcher::FetchError, /BinaryNotFoundError/)
    end

    it "closes the browser even when fetching fails" do
      allow(page).to receive(:go_to).and_raise(StandardError, "navigation failed")

      expect(browser).to receive(:quit)
      expect { described_class.fetch_html(url) }.to raise_error(StandardError, "navigation failed")
    end
  end
end
