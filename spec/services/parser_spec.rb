require "rails_helper"

RSpec.describe PriceTracker::Parser do
  let(:html) { File.read(Rails.root.join("spec/fixtures/files/baly_melancia_sem_acucar.html")) }
  it "extracts name and price in cents" do
    result = described_class.parse(html)

    expect(result.name).to eq("Baly energetico melancia zero açucar 473ML")
    expect(result.price_cents).to eq(490)
  end

  it "raises ParseError when the price element is missing" do
    expect { described_class.parse("<html></html>") }
      .to raise_error(PriceTracker::Parser::ParseError)
  end
end
