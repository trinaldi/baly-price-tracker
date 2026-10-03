require "net/http"
require "openssl"

module PriceTracker
  class Fetcher
    class FetchError < StandardError; end

    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 10
    USER_AGENT = "Mozilla/5.0 (compatible; PriceTracker/1.0)".freeze
    NETWORK_ERRORS = [
      Net::OpenTimeout,
      Net::ReadTimeout,
      SocketError,
      Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      OpenSSL::SSL::SSLError,
      URI::InvalidURIError
    ].freeze

    def self.get(url, headers: {})
      uri = URI.parse(url)

      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = USER_AGENT
      headers.each { |key, value| request[key] = value }

      response = Net::HTTP.start(
        uri.host, uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout:  OPEN_TIMEOUT,
        read_timeout: READ_TIMEOUT
      ) { |http| http.request(request) }

      unless response.is_a?(Net::HTTPSuccess)
        raise FetchError, "unexpected status #{response.code} for #{url}"
      end

      response.body

    rescue *NETWORK_ERRORS => e
      raise FetchError, "#{e.class}: #{e.message}"
    end
  end
end
