def load_price_tracker_env
  env_file = File.expand_path("~/.config/price-tracker/env")

  unless File.exist?(env_file)
    raise "Environment file not found: #{env_file}"
  end

  File.foreach(env_file) do |line|
    line = line.strip
    next if line.empty? || line.start_with?("#")

    key, value = line.split("=", 2)
    next unless key && value

    ENV[key] = value.gsub(/\A['"]|['"]\z/, "")
  end
end

namespace :price do
  desc "Sync products from config/products.yml"
  task sync: :environment do
    load_price_tracker_env
    PriceTracker::ProductSync.call
  end

  desc "Check the price of every product"
  task check: :sync do
    CheckPriceJob.perform_now
  end

  desc "Send an email with the current prices"
  task report: :environment do
    load_price_tracker_env
    PriceMailer.price_report(Product.all).deliver_now
  end
end
