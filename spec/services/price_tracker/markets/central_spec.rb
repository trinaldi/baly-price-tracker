require 'rails_helper'

RSpec.describe PriceTracker::Markets::Central do
  describe '.host' do
    it 'returns the market host' do
      expect(described_class.host).to eq('www.supercentralonline.com.br')
    end
  end

  describe '.available?' do
    context 'when the product is available' do
      let(:html) do
        <<~HTML
          <vip-produto>
            <div class="grid">
              <vip-produto-preco class="block m-3">
                <vip-produto-preco-valor>
                  <span data-cy="preco">R$ 5,99</span>
                </vip-produto-preco-valor>
              </vip-produto-preco>

              <button aria-label="Adicionar produto ao carrinho">
                Adicionar ao carrinho
              </button>
            </div>
          </vip-produto>
        HTML
      end

      it 'returns true' do
        expect(described_class.available?(html)).to be(true)
      end
    end

    context 'when the product is unavailable' do
      let(:html) do
        <<~HTML
          <vip-produto>
            <div class="grid">
              <p class="vip-color-error-main">Produto indisponível</p>

              <vip-button data-cy="button-avise-me">
                <button>Avise-me quando chegar</button>
              </vip-button>
            </div>
          </vip-produto>
        HTML
      end

      it 'returns false' do
        expect(described_class.available?(html)).to be(false)
      end
    end

    context 'when only carousel products have prices' do
      let(:html) do
        <<~HTML
          <vip-produto>
            <div class="grid">
              <p class="vip-color-error-main">Produto indisponível</p>

              <vip-button data-cy="button-avise-me">
                <button>Avise-me quando chegar</button>
              </vip-button>
            </div>

            <div class="carousel">
              <vip-produto-preco class="block m-3">
                <vip-produto-preco-valor>
                  <span data-cy="preco">R$ 5,99</span>
                </vip-produto-preco-valor>
              </vip-produto-preco>
            </div>
          </vip-produto>
        HTML
      end

      it 'returns false' do
        expect(described_class.available?(html)).to be(false)
      end
    end

    context 'when availability markers are missing' do
      let(:html) do
        <<~HTML
          <vip-produto>
            <div class="grid">
              <p>Informações do produto</p>
            </div>
          </vip-produto>
        HTML
      end

      it 'raises a ParseError' do
        expect {
          described_class.available?(html)
        }.to raise_error(
          PriceTracker::Markets::ParseError,
          'availability markers not found'
        )
      end
    end

    context 'when the product panel is missing' do
      it 'raises a ParseError' do
        expect {
          described_class.available?('<html><body></body></html>')
        }.to raise_error(
          PriceTracker::Markets::ParseError,
          'product panel not found'
        )
      end
    end
  end

  describe '.price_cents' do
    context 'when the price is valid' do
      let(:html) do
        <<~HTML
          <vip-produto>
            <div class="grid">
              <vip-produto-preco class="block m-3">
                <vip-produto-preco-valor>
                  <span data-cy="preco">R$ 5,99</span>
                </vip-produto-preco-valor>
              </vip-produto-preco>
            </div>
          </vip-produto>
        HTML
      end

      it 'returns the price in cents' do
        expect(described_class.price_cents(html)).to eq(599)
      end
    end

    context 'when the price contains thousands separator' do
      let(:html) do
        <<~HTML
          <vip-produto>
            <div class="grid">
              <vip-produto-preco class="block m-3">
                <vip-produto-preco-valor>
                  <span data-cy="preco">R$ 1.234,56</span>
                </vip-produto-preco-valor>
              </vip-produto-preco>
            </div>
          </vip-produto>
        HTML
      end

      it 'returns the price in cents' do
        expect(described_class.price_cents(html)).to eq(123456)
      end
    end

    context 'when the main product price is missing' do
      let(:html) do
        <<~HTML
          <vip-produto>
            <div class="grid">
              <p>Informações do produto</p>
            </div>
          </vip-produto>
        HTML
      end

      it 'raises a ParseError' do
        expect {
          described_class.price_cents(html)
        }.to raise_error(
          PriceTracker::Markets::ParseError,
          'availability markers not found'
        )
      end
    end

    context 'when the price value is missing' do
      let(:html) do
        <<~HTML
          <vip-produto>
            <div class="grid">
              <vip-produto-preco class="block m-3">
                <vip-produto-preco-valor>
                  <span data-cy="unidade">/un</span>
                </vip-produto-preco-valor>
              </vip-produto-preco>
            </div>
          </vip-produto>
        HTML
      end

      it 'raises a ParseError' do
        expect {
          described_class.price_cents(html)
        }.to raise_error(
          PriceTracker::Markets::ParseError,
          'price value not found'
        )
      end
    end

    context 'when the price is invalid' do
      let(:html) do
        <<~HTML
          <vip-produto>
            <div class="grid">
              <vip-produto-preco class="block m-3">
                <vip-produto-preco-valor>
                  <span data-cy="preco">Preço indisponível</span>
                </vip-produto-preco-valor>
              </vip-produto-preco>
            </div>
          </vip-produto>
        HTML
      end

      it 'raises a ParseError' do
        expect {
          described_class.price_cents(html)
        }.to raise_error(
          PriceTracker::Markets::ParseError,
          /invalid price/
        )
      end
    end

    context 'when the price exists only in the carousel' do
      let(:html) do
        <<~HTML
          <vip-produto>
            <div class="grid">
              <p class="vip-color-error-main">Produto indisponível</p>

              <vip-button data-cy="button-avise-me">
                <button>Avise-me quando chegar</button>
              </vip-button>
            </div>

            <div class="carousel">
              <vip-produto-preco class="block m-3">
                <vip-produto-preco-valor>
                  <span data-cy="preco">R$ 5,99</span>
                </vip-produto-preco-valor>
              </vip-produto-preco>
            </div>
          </vip-produto>
        HTML
      end

      it 'returns nil' do
        expect(described_class.price_cents(html)).to be_nil
      end
    end

    context 'when the product panel is missing' do
      it 'raises a ParseError' do
        expect {
          described_class.price_cents('<html><body></body></html>')
        }.to raise_error(
          PriceTracker::Markets::ParseError,
          'product panel not found'
        )
      end
    end
  end
end
