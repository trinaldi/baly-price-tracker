require "bigdecimal"
require "ferrum"

module PriceTracker
  module Markets
    class TendaAtacado
      extend Defaults

      AVAILABLE_SELECTOR   = ".ButtonBuyComponent".freeze
      UNAVAILABLE_SELECTOR = ".ProductNotAvailableComponent".freeze
      PRICE_SELECTOR       = ".SimplePriceComponent".freeze
      PRICE_PATTERN        = /\d+(?:\.\d{3})*,\d{2}/

      BROWSER_TIMEOUT      = 30
      NETWORK_IDLE_TIMEOUT = 10
      AVAILABILITY_TIMEOUT = 15
      STABLE_FOR           = 2

      def self.host = "www.tendaatacado.com.br"
      def self.cookie = nil

      def self.fetch_html(url)
        browser = Ferrum::Browser.new(timeout: BROWSER_TIMEOUT, process_timeout: BROWSER_TIMEOUT)
        page = browser.create_page
        page.go_to(url)
        wait_for_network_idle(page)
        wait_for_stable_availability(page)
      rescue Ferrum::Error => e
        raise Fetcher::FetchError, "#{e.class}: #{e.message}"
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

      def self.wait_for_network_idle(page)
        page.network.wait_for_idle(timeout: NETWORK_IDLE_TIMEOUT)
      rescue Ferrum::TimeoutError
        nil # some pages never go idle; the loop below still decides
      end

      def self.wait_for_stable_availability(page)
        deadline = monotonic_now + AVAILABILITY_TIMEOUT
        state = nil
        state_since = nil

        loop do
          now = monotonic_now
          html = page.body
          current = availability_state(Nokogiri::HTML(html))

          if current != state
            state = current
            state_since = now
          elsif state && now - state_since >= STABLE_FOR
            return html
          end

          raise ParseError, "availability markers did not stabilize" if now >= deadline

          sleep 0.2
        end
      end

      def self.availability_state(doc)
        return :unavailable if doc.at_css(UNAVAILABLE_SELECTOR)

        :available if doc.at_css(AVAILABLE_SELECTOR)
      end

      def self.monotonic_now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      private_class_method :wait_for_network_idle, :wait_for_stable_availability,
                           :availability_state, :monotonic_now
    end
  end
end
