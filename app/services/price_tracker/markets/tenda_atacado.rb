require "bigdecimal"
require "ferrum"

module PriceTracker
  module Markets
    class TendaAtacado
      AVAILABLE_SELECTOR   = ".ButtonBuyComponent".freeze
      UNAVAILABLE_SELECTOR = ".ProductNotAvailableComponent".freeze
      PRICE_SELECTOR       = ".SimplePriceComponent".freeze
      PRICE_PATTERN        = /\d+(?:\.\d{3})*,\d{2}/

      def self.host = "www.tendaatacado.com.br"
      def self.cookie = nil
      def self.club_price_cents(_html) = nil

      def self.fetch_html(url)
        browser = Ferrum::Browser.new
        page = browser.create_page

        page.go_to(url)

        timeout = 15
        stable_for = 2
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
        state = nil
        state_since = nil

        loop do
          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          doc = Nokogiri::HTML(page.body)

          current_state =
            if doc.at_css(UNAVAILABLE_SELECTOR)
              :unavailable
            elsif doc.at_css(AVAILABLE_SELECTOR)
              :available
            end

          if current_state != state
            state = current_state
            state_since = now
          elsif state && now - state_since >= stable_for
            return page.body
          end

          if now >= deadline
            raise ParseError, "availability markers did not stabilize"
          end

          sleep 0.2
        end
      ensure
        browser&.quit
      end

      def self.available?(html)
        doc = Nokogiri::HTML(html)
        return false if doc.at_css(UNAVAILABLE_SELECTOR)
        return true if doc.at_css(AVAILABLE_SELECTOR)

        raise ParseError, "availability markers not found"
      end

      def self.price_cents(html)
        node = Nokogiri::HTML(html).at_css(PRICE_SELECTOR)
        raise ParseError, "price element not found" if node.nil?

        match = node.text[PRICE_PATTERN]
        raise ParseError, "invalid price: #{node.text.inspect}" if match.nil?

        (BigDecimal(match.delete(".").tr(",", ".")) * 100).round.to_i
      end
    end
  end
end
