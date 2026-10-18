module PriceTracker
  class ProductSync
    CONFIG_KEYS = %w[name url].freeze
    DEFAULT_PATH = Rails.root.join("config/products.yml")

    def self.call(path = DEFAULT_PATH)
      new(path).call
    end

    def initialize(path)
      @path = path
    end

    def call
      entries.map do |slug, attributes|
        product = Product.find_or_initialize_by(slug: slug)
        product.update!(attributes.slice(*CONFIG_KEYS))
        product
      end
    end

    private

    def entries
      YAML.safe_load_file(@path).fetch("products")
    end
  end
end
