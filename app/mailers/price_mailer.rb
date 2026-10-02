class PriceMailer < ApplicationMailer
  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.price_mailer.price_changed.subject
  #
  def price_changed
    @greeting = "Hi"

    mail to: "to@example.org"
  end

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.price_mailer.failed.subject
  #
  def failed
    @greeting = "Hi"

    mail to: "to@example.org"
  end
end
