module PriceTracker
  class Runner
    Prices = Data.define(:regular_cents, :club_cents)

    def self.call(product)
      new(product).call
    end

    def initialize(product)
      @product = product
    end

    def call
      previous = Prices.new(regular_cents: @product.price_cents, club_cents: @product.club_price_cents)
      current = fetch_and_parse
      check = record_success(current, previous)

      notify(previous, current)
      check
    rescue Fetcher::FetchError, Markets::ParseError, Markets::UnknownMarket, Markets::ConfigError => e
      record_failure(e)
    end

    private

    def fetch_and_parse
      market = Markets.for(@product.url)

      html =
        if market.respond_to?(:fetch_html)
          market.fetch_html(@product.url)
        else
          Fetcher.get(@product.url, headers: request_headers(market))
        end

      Prices.new(
        regular_cents: market.price_cents(html),
        club_cents: market.club_price_cents(html)
      )
    end

    def request_headers(market)
      { "Cookie" => market.cookie }
    end

    def record_success(current, previous)
      now = Time.current

      ActiveRecord::Base.transaction do
        check = @product.price_checks.create!(
          status: "ok",
          price_cents: current.regular_cents,
          club_price_cents: current.club_cents,
          checked_at: now
        )

        attributes = { price_cents: current.regular_cents, club_price_cents: current.club_cents }
        attributes[:last_changed_at] = now if regular_changed?(previous, current)
        @product.update!(attributes)

        check
      end
    end

    def baseline?(previous)
      previous.regular_cents.nil?
    end

    def regular_changed?(previous, current)
      !baseline?(previous) && previous.regular_cents != current.regular_cents
    end

    def club_deal?(previous, current)
      return false if baseline?(previous)
      return false if current.club_cents.nil?

      current.club_cents < current.regular_cents && current.club_cents != previous.club_cents
    end

    def notify(previous, current)
      if regular_changed?(previous, current)
        PriceMailer.price_changed(@product, previous.regular_cents, current.regular_cents).deliver_now
      end

      if club_deal?(previous, current)
        PriceMailer.club_offer(@product, current.club_cents, current.regular_cents).deliver_now
      end
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
