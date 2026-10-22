class PriceMailer < ApplicationMailer
  def price_changed(product, old_cents, new_cents)
    @product = product
    @old_price = format_brl(old_cents)
    @new_price = format_brl(new_cents)

    mail to: recipient, subject: "Preço mudou: #{product.name}"
  end

  def failed(product, message)
    @product = product
    @message = message

    mail to: recipient, subject: "Falha ao verificar #{product.name}"
  end

  def price_report(products)
    @products = products.map do |product|
      market = PriceTracker::Markets.for(product.url)

      html = PriceTracker::Fetcher.get(
        product.url,
        headers: { "Cookie" => market.cookie }
      )

      {
        name: product.name,
        url: product.url,
        price: format_brl(market.price_cents(html)),
        error: nil
      }
    rescue StandardError => e
      {
        name: product.name,
        url: product.url,
        price: nil,
        error: "#{e.class}: #{e.message}"
      }
    end

    mail to: recipient, subject: "Relatório de preços atuais"
  end

  def club_offer(product, club_cents, regular_cents)
    @product = product
    @club_price = format_brl(club_cents)
    @regular_price = format_brl(regular_cents)

    mail to: recipient, subject: "Preço do clube: #{product.name}"
  end

  private

  def recipient
    ENV.fetch("PRICE_ALERT_EMAIL")
  end

  def format_brl(cents)
    format("R$ %.2f", cents / 100.0).tr(".", ",")
  end
end
