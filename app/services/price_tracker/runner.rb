module PriceTracker
  class Runner
    def self.call(product)
      new(product).call
    end

    def initialize(product)
      @product = product
    end

    def call
      previous_price = last_ok_price
      result = fetch_and_parse

      check = @product.price_checks.create!(
        status: "ok",
        price_cents: result.price_cents,
        checked_at: Time.current
      )

      notify_price_chance(previous_price, check.price_cents)
      check

    rescue Fetcher::FetchError, Parser::ParseError => e
      record_failure(e)
    end

    private

    def last_ok_price
      @product.price_checks.where(status: "ok").order(:checked_at).last&.price_cents
    end

    def fetch_and_parse
      html = Fetcher.get(@product.url, headers: request_headers)
      Parser.parse(html)
    end

    def request_headers
      @product.cookie.present? ? { "Cookie" => @product.cookie } : {}
    end

    def notify_price_chance(previous_price, current_price)
      update_timestamp
      return if previous_price.nil? || previous_price == current_price

      PriceMailer.price_changed(@product, previous_price, current_price).deliver_now
    end

    def record_failure(error)
      check = @product.price_checks.create!(
        status: "error",
        error_message: error.message,
        checked_at: Time.current
      )
      PriceMailer.failed(@product, error.message).deliver_now
      check
    end

    def update_timestamp
      @product.update!(updated_at: Time.current)
    end
  end
end
