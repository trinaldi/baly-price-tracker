module PriceTracker
  module Markets
    class Simao
      PRICE_SELECTOR = "#variacaoPreco".freeze

      def self.host = "www.simaodoces.com.br"
      def self.cookie = "LOJA=1106817"
      def self.club_price_cents(_html) = nil

      def self.price_cents(html)
        node = Nokogiri::HTML(html).at_css(PRICE_SELECTOR)
        raise ParseError, "price element not found" if node.nil?

        cents = node.text.gsub(/\D/, "").to_i
        raise ParseError, "invalid price: #{node.text.inspect}" if cents.zero?

        cents
      end
    end
  end
end
