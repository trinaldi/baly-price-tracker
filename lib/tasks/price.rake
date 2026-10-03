namespace :price do
  desc "Check the price of every product"
  task check: :environment do
    CheckPriceJob.perform_now
  end
end
