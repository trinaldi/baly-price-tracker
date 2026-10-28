require "bigdecimal"

module PriceTracker
  module Markets
    class Jauserve
      extend Defaults

      STORE_ID = "3".freeze
      PRICE_SELECTOR = "span.sales span.value[content]".freeze

      def self.host = "www.jauserve.com.br"

      def self.cookie(cep: ENV["JAUSERVE_CEP"])
        raise Markets::ConfigError, "JAUSERVE_CEP is not set" if cep.blank?

        "dw_storeid=#{STORE_ID}; dw_shippostalcode=#{cep}"
      end

      def self.price_cents(html)
        node = Nokogiri::HTML(html).at_css(PRICE_SELECTOR)
        raise Markets::ParseError, "price element not found" if node.nil?

        raw = node["content"]

        begin
          (BigDecimal(raw) * 100).round.to_i
        rescue ArgumentError, FloatDomainError
          raise Markets::ParseError, "invalid price: #{raw.inspect}"
        end
      end

      def self.available?(html)
        doc = Nokogiri::HTML(html)
        !doc.at_css(PRICE_SELECTOR).nil?
      end
    end
  end
end
