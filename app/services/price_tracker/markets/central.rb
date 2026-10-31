require 'bigdecimal'
require 'ferrum'
require 'nokogiri'

module PriceTracker
  module Markets
    class Central
      extend Defaults

      PRODUCT_CONTAINER_SELECTOR = 'vip-produto > div'.freeze
      PRICE_SELECTOR = 'vip-produto-preco.block.m-3 vip-produto-preco-valor'.freeze
      PRICE_VALUE_SELECTOR = 'span[data-cy="preco"]'.freeze
      UNAVAILABLE_SELECTOR = '[data-cy="button-avise-me"]'.freeze

      PRODUCT_CONTENT_SELECTOR = [
        "#{PRODUCT_CONTAINER_SELECTOR} #{UNAVAILABLE_SELECTOR}",
        "#{PRODUCT_CONTAINER_SELECTOR} #{PRICE_SELECTOR}"
      ].join(', ').freeze

      PRICE_PATTERN = /\d+(?:\.\d{3})*,\d{2}/

      BROWSER_TIMEOUT = 120
      PRODUCT_CONTENT_TIMEOUT = 60
      POLL_INTERVAL = 0.1

      def self.store_name = 'Central Supermercados'
      def self.host = 'www.supercentralonline.com.br'
      def self.cookie = nil

      def self.fetch_html(url)
        browser = Ferrum::Browser.new(
          timeout: BROWSER_TIMEOUT,
          process_timeout: BROWSER_TIMEOUT
        )

        page = browser.create_page
        page.go_to(url)

        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) +
          PRODUCT_CONTENT_TIMEOUT

        until page.at_css(PRODUCT_CONTENT_SELECTOR)
          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          if now >= deadline
            raise Fetcher::FetchError,
              'timed out waiting for product content'
          end

          sleep POLL_INTERVAL
        end

        page.body
      rescue Ferrum::Error => e
        raise Fetcher::FetchError, "#{e.class}: #{e.message}"
      ensure
        browser&.quit
      end

      def self.available?(html)
        container = product_container(html)

        return false if container.at_css(UNAVAILABLE_SELECTOR)
        return true if container.at_css(PRICE_SELECTOR)

        raise Markets::ParseError, 'availability markers not found'
      end

      def self.price_cents(html)
        return nil unless available?(html)

        container = product_container(html)

        node = container.at_css(PRICE_SELECTOR)
        raise Markets::ParseError, 'price element not found' if node.nil?

        raw = node.at_css(PRICE_VALUE_SELECTOR)&.text&.strip
        raise Markets::ParseError, 'price value not found' if raw.nil?

        match = raw.match(PRICE_PATTERN)
        raise Markets::ParseError, "invalid price: #{raw.inspect}" if match.nil?

        (BigDecimal(match[0].delete('.').tr(',', '.')) * 100).round.to_i
      end

      def self.product_panel(html)
        document = Nokogiri::HTML(html)

        panel = document.at_css('vip-produto')
        raise Markets::ParseError, 'product panel not found' if panel.nil?

        panel
      end

      def self.product_container(html)
        panel = product_panel(html)

        container = panel.element_children.find do |element|
          element.name == 'div'
        end

        raise Markets::ParseError, 'product container not found' if container.nil?

        container
      end

      private_class_method :product_panel, :product_container
    end
  end
end
