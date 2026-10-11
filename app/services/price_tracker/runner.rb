module PriceTracker
  class Runner
    def self.call(product)
      new(product).call
    end

    def initialize(product)
      @product = product
    end

    def call
      previous_price = @product.price_cents
      result = fetch_and_parse
      check = record_success(result.price_cents, previous_price)

      notify_price_change(previous_price, check.price_cents)
      check
    rescue Fetcher::FetchError, Parser::ParseError => e
      record_failure(e)
    end

    private

    def fetch_and_parse
      html = Fetcher.get(@product.url, headers: request_headers)
      Parser.parse(html)
    end

    def request_headers
      @product.cookie.present? ? { "Cookie" => @product.cookie } : {}
    end

    def record_success(price_cents, previous_price)
      now = Time.current

      ActiveRecord::Base.transaction do
        check = @product.price_checks.create!(
          status: "ok",
          price_cents: price_cents,
          checked_at: now
        )

        attributes = { price_cents: price_cents }
        attributes[:last_changed_at] = now if price_changed?(previous_price, price_cents)
        @product.update!(attributes)

        check
      end
    end

    def price_changed?(previous_price, current_price)
      !previous_price.nil? && previous_price != current_price
    end

    def notify_price_change(previous_price, current_price)
      return unless price_changed?(previous_price, current_price)

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
  end
end
