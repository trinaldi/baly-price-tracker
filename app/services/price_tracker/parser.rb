module PriceTracker
  class Parser
    class ParseError < StandardError; end

    Result = Data.define(:name, :price_cents)

    def self.parse(html)
      doc = Nokogiri::HTML(html)

      price_node = doc.at_css("#variacaoPreco")
      name_node = doc.at_css("h1.product-name")

      raise ParseError, "price element not found" if price_node.nil?
      raise ParseError, "name element not found" if name_node.nil?

      price_cents = price_node.text.gsub(/\D/, "").to_i
      raise ParseError, "invalid price: #{price_node.text.inspect}" if price_cents.zero?

      Result.new(name: name_node.text.strip, price_cents: price_cents)
    end
  end
end
