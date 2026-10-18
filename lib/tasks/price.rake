namespace :price do
  desc "Sync products from config/products.yml"
  task sync: :environment do
    PriceTracker::ProductSync.call
  end

  desc "Check the price of every product"
  task check: :sync do
    CheckPriceJob.perform_now
  end

  desc "Send an email with the current prices"
  task report: :environment do
    PriceMailer.price_report(Product.all).deliver_now
  end
end
