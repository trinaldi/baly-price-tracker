class CheckPriceJob < ApplicationJob
  queue_as :default

  def perform
    failures = []

    Product.find_each do |product|
      PriceTracker::Runner.call(product)
    rescue StandardError => e
      Rails.logger.error("[CheckPriceJob] #{product.slug}: #{e.class}: #{e.message}")
      failures << "#{product.slug}: #{e.class}: #{e.message}"
    end

    raise "CheckPriceJob failed for: #{failures.join(', ')}" if failures.any?
  end
end
