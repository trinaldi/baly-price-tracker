class CheckPriceJob < ApplicationJob
  queue_as :default

  def perform
    Product.find_each { |product| PriceTracker::Runner.call(product) }
  end
end
