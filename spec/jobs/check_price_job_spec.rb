require "rails_helper"

RSpec.describe CheckPriceJob, type: :job do
  it "keeps going when one product raises, and fails at the end" do
    a = Product.create!(name: "A", slug: "a", url: "https://example.com/a")
    b = Product.create!(name: "B", slug: "b", url: "https://example.com/b")
    allow(PriceTracker::Runner).to receive(:call)
    allow(PriceTracker::Runner).to receive(:call).with(a).and_raise("boom")

    expect { described_class.perform_now }.to raise_error(/a: RuntimeError/)
    expect(PriceTracker::Runner).to have_received(:call).with(b)
  end
end
