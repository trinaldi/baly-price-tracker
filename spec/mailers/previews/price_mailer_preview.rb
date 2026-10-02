# Preview all emails at http://localhost:3000/rails/mailers/price_mailer_mailer
class PriceMailerPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/price_mailer_mailer/price_changed
  def price_changed
    PriceMailer.price_changed
  end

  # Preview this email at http://localhost:3000/rails/mailers/price_mailer_mailer/failed
  def failed
    PriceMailer.failed
  end

end
