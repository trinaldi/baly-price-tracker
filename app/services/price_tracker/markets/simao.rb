module PriceTracker
  module Markets
    class Simao
      def self.host = "www.simaodoces.com.br"
      def self.cookie = "LOJA=1106817"

      def self.price_cents(html)
        Parser.parse(html).price_cents
      end
    end
  end
end
