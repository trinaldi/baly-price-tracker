namespace :products do
  desc 'Synchronize products with config/products.yml'
  task sync: :environment do
    config = YAML.safe_load_file(Rails.root.join('config/products.yml'))
    products = config.fetch('products')

    expected = products.map do |slug, attributes|
      {
        slug: slug,
        name: attributes.fetch('name').strip,
        url: attributes.fetch('url').strip
      }
    end

    expected_slugs = expected.map { |product| product[:slug] }

    existing = Product.all.to_a.index_by(&:slug)

    to_create = expected.reject do |product|
      existing.key?(product[:slug])
    end

    to_update = expected.select do |product|
      current = existing[product[:slug]]

      current && (
        current.name != product[:name] ||
        current.url != product[:url]
      )
    end

    to_remove = Product.where.not(slug: expected_slugs).to_a

    puts 'Products synchronization'
    puts '------------------------'
    puts "To create: #{to_create.size}"
    puts "To update: #{to_update.size}"
    puts "To remove: #{to_remove.size}"

    to_remove.each do |product|
      puts "  Remove: #{product.name} (#{product.slug})"
    end

    unless ENV['CONFIRM'] == '1'
      puts
      puts 'Dry run. No changes were made.'
      puts 'Run with CONFIRM=1 to apply changes.'
      next
    end

    Product.transaction do
      expected.each do |attributes|
        product = Product.find_or_initialize_by(slug: attributes[:slug])
        product.update!(attributes)
      end

      Product.where.not(slug: expected_slugs).destroy_all
    end

    puts
    puts 'Synchronization completed.'
  end
end
