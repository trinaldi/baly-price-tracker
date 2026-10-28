require "bigdecimal"

module PriceTracker
  module Markets
    class Furlanetti
      extend Defaults

      REGULAR_PRICE_SELECTOR = '[data-testid="price-display-price"]'.freeze
      OFFER_HEADER_SELECTOR  = '[data-testid="offer-panel-header"]'.freeze
      PRICE_PATTERN = /\d+(?:\.\d{3})*,\d{2}/

      def self.host = "furlanetti.com.br"
      def self.available?(_html) = true

      def self.cookie = ""

      def self.price_cents(html)
        node = Nokogiri::HTML(html).at_css(REGULAR_PRICE_SELECTOR)
        raise Markets::ParseError, "price element not found" if node.nil?

        to_cents(node.text, what: "price")
      end

      def self.club_price_cents(html)
        header = Nokogiri::HTML(html).css(OFFER_HEADER_SELECTOR).find { |n| n.text.include?("Clube") }
        return nil if header.nil?

        to_cents(header.text, what: "club price")
      end

      def self.to_cents(text, what:)
        match = text[PRICE_PATTERN]
        raise Markets::ParseError, "invalid #{what}: #{text.inspect}" if match.nil?

        (BigDecimal(match.delete(".").tr(",", ".")) * 100).round.to_i
      end

      private_class_method :to_cents
    end
  end
end
