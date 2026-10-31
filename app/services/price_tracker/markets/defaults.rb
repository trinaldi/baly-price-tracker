module PriceTracker
  module Markets
    module Defaults
      def store_name = name.demodulize
      def fetch_url(url) = url

      def headers
        { 'Cookie' => cookie }
      end

      def fetch_html(url) = Fetcher.get(url, headers: headers)

      def available?(_html) = true
      def club_price_cents(_html) = nil
    end
  end
end
