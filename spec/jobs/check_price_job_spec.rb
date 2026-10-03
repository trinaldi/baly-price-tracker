require "rails_helper"

RSpec.describe CheckPriceJob, type: :job do
  it "runs the runner for every product" do
    a = Product.create!(name: "A", url: "https://example.com/a")
    b = Product.create!(name: "B", url: "https://example.com/b")
    allow(PriceTracker::Runner).to receive(:call)

    described_class.perform_now

    expect(PriceTracker::Runner).to have_received(:call).with(a)
    expect(PriceTracker::Runner).to have_received(:call).with(b)
  end
end
