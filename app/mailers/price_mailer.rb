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

  def recipient
    ENV.fetch("PRICE_ALERT_EMAIL")
  end

  def format_brl(cents)
    format("R$ %.2f", cents / 100.0).tr(".", ",")
  end
end
