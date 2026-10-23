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
        <div class="ProductNotAvailableComponent">
          Produto indisponível
        </div>
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
      html = <<~HTML
        <div class="ButtonBuyComponent">Adicionar</div>
        <div class="ProductNotAvailableComponent">Indisponível</div>
      HTML

      expect(described_class.available?(html)).to be(false)
    end

    it "raises an error when availability markers are missing" do
      expect {
        described_class.available?("<html><body>Produto</body></html>")
      }.to raise_error(PriceTracker::Markets::ParseError)
    end
  end

  describe ".price_cents" do
    it "parses a Brazilian price into cents" do
      expect(described_class.price_cents(available_html)).to eq(3999)
    end

    it "parses prices with thousands separators" do
      html = '<div class="SimplePriceComponent">R$ 1.234,56</div>'

      expect(described_class.price_cents(html)).to eq(123456)
    end

    it "raises an error when the price element is missing" do
      expect {
        described_class.price_cents("<html><body>Produto</body></html>")
      }.to raise_error(PriceTracker::Markets::ParseError, "price element not found")
    end

    it "raises an error when the price is invalid" do
      html = '<div class="SimplePriceComponent">Consulte o preço</div>'

      expect {
        described_class.price_cents(html)
      }.to raise_error(PriceTracker::Markets::ParseError, /invalid price/)
    end
  end

  describe ".fetch_html" do
    let(:url) { "https://www.tendaatacado.com.br/produto/exemplo" }
    let(:browser) { double("Ferrum::Browser") }
    let(:page) { double("Ferrum::Page") }

    before do
      allow(Ferrum::Browser).to receive(:new).and_return(browser)
      allow(browser).to receive(:create_page).and_return(page)
      allow(page).to receive(:go_to).with(url)
      allow(browser).to receive(:quit)
    end

    it "waits for availability to stabilize before returning the HTML" do
      clock = 0.0

      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC) { clock }

      allow(described_class).to receive(:sleep) do |duration|
        clock += duration
      end

      allow(page).to receive(:body) do
        clock < 0.6 ? available_html : unavailable_html
      end

      html = described_class.fetch_html(url)

      expect(described_class.available?(html)).to be(false)
      expect(Nokogiri::HTML(html).at_css(
        described_class::UNAVAILABLE_SELECTOR
      )).not_to be_nil
    end

    it "raises an error when availability markers never appear" do
      clock = 0.0

      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC) { clock }

      allow(described_class).to receive(:sleep) do |duration|
        clock += duration
      end

      allow(page).to receive(:body).and_return("<html></html>")

      expect {
        described_class.fetch_html(url)
      }.to raise_error(
        PriceTracker::Markets::ParseError,
        "availability markers did not stabilize"
      )
    end

    it "closes the browser even when fetching fails" do
      allow(page).to receive(:go_to).and_raise(StandardError, "navigation failed")

      expect(browser).to receive(:quit)

      expect {
        described_class.fetch_html(url)
      }.to raise_error(StandardError, "navigation failed")
    end
  end
end
