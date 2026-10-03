require "rails_helper"

RSpec.describe PriceTracker::Fetcher do
  let(:url) { "https://www.simaodoces.com.br/mercearia-/baly-energetico-melancia-zero-acucar-473ml" }

  it "returns the response body on success" do
    stub_request(:get, url).to_return(status: 200, body: "<html>ok</html>")

    expect(described_class.get(url)).to eq("<html>ok</html>")
  end

  it "raises FetchError on a non-2xx status" do
    stub_request(:get, url).to_return(status: 500)

    expect { described_class.get(url) }
      .to raise_error(PriceTracker::Fetcher::FetchError)
  end

  it "raises FetchError on timeout" do
    stub_request(:get, url).to_timeout

    expect { described_class.get(url) }
      .to raise_error(PriceTracker::Fetcher::FetchError)
  end

  it "sends custom headers" do
    stub = stub_request(:get, url)
      .with(headers: { "Cookie" => "LOJA=1106817" })
      .to_return(status: 200, body: "ok")

    described_class.get(url, headers: { "Cookie" => "LOJA=1106817" })

    expect(stub).to have_been_requested
  end
end
