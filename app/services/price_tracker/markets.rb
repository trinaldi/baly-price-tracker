module PriceTracker
  module Markets
    class UnknownMarket < StandardError; end
    class ConfigError < StandardError; end
    class ParseError < StandardError; end

    def self.all
      [ Simao, Jauserve, Furlanetti, TendaAtacado ]
    end

    def self.for(url)
      host = URI.parse(url).host
      all.find { |market| market.host == host } or
        raise UnknownMarket, "no market for #{host}"
    end
  end
end
