module PriceTracker
  module Markets
    module Defaults
      def fetch_html(url) = Fetcher.get(url, headers: { "Cookie" => cookie })
      def available?(_html) = true
      def club_price_cents(_html) = nil
    end
  end
end
