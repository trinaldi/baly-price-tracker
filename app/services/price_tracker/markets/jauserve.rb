require "bigdecimal"

module PriceTracker
  module Markets
    class Jauserve
      STORE_ID = "3".freeze
      PRICE_SELECTOR = "span.sales span.value[content]".freeze
      def self.club_price_cents(_html) = nil

      def self.host = "www.jauserve.com.br"

      def self.cookie(cep: ENV["JAUSERVE_CEP"])
        raise Markets::ConfigError, "JAUSERVE_CEP is not set" if cep.blank?

        "dw_storeid=#{STORE_ID}; dw_shippostalcode=#{cep}"
      end

      def self.price_cents(html)
        node = Nokogiri::HTML(html).at_css(PRICE_SELECTOR)
        raise Parser::ParseError, "price element not found" if node.nil?

        raw = node["content"]

        begin
          (BigDecimal(raw) * 100).round.to_i
        rescue ArgumentError, FloatDomainError
          raise Parser::ParseError, "invalid price: #{raw.inspect}"
        end
      end
    end
  end
end
