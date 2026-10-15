require "rails_helper"
require "tempfile"

RSpec.describe PriceTracker::ProductSync do
  let(:file) { Tempfile.new([ "products", ".yml" ]) }

  after { file.close! }

  def sync(yaml)
    file.rewind
    file.truncate(0)
    file.write(yaml)
    file.flush
    described_class.call(file.path)
  end

  let(:yaml) do
    <<~YAML
      products:
        baly:
          name: "Baly"
          url: "https://example.com/baly"
          cookie: "LOJA=1"
        agua:
          name: "Água"
          url: "https://example.com/agua"
    YAML
  end

  it "creates the products from the file" do
    expect { sync(yaml) }.to change(Product, :count).by(2)

    baly = Product.find_by!(slug: "baly")
    expect(baly.name).to eq("Baly")
    expect(baly.cookie).to eq("LOJA=1")
  end

  it "does not duplicate products when run twice" do
    sync(yaml)

    expect { sync(yaml) }.not_to change(Product, :count)
  end

  it "updates the config but keeps price and history" do
    sync(yaml)
    baly = Product.find_by!(slug: "baly")
    baly.update!(price_cents: 490)
    baly.price_checks.create!(status: "ok", price_cents: 490, checked_at: Time.current)

    sync(yaml.sub("https://example.com/baly", "https://example.com/baly-novo"))

    baly.reload
    expect(baly.url).to eq("https://example.com/baly-novo")
    expect(baly.price_cents).to eq(490)
    expect(baly.price_checks.count).to eq(1)
  end

  it "keeps products that were removed from the file" do
    sync(yaml)

    sync(<<~YAML)
      products:
        baly:
          name: "Baly"
          url: "https://example.com/baly"
    YAML

    expect(Product.find_by(slug: "agua")).to be_present
  end

  it "raises when an entry has no url" do
    expect do
      sync(<<~YAML)
        products:
          baly:
            name: "Baly"
      YAML
    end.to raise_error(ActiveRecord::RecordInvalid)
  end
end
