class Finance::ProviderCatalog
  PROVIDERS = {
    'asaas' => { markets: %w[BR], roles: %w[payment invoicing], available: true },
    'manual' => { markets: %w[BR PT OTHER], roles: %w[payment], available: true },
    'ifthenpay' => { markets: %w[PT], roles: %w[payment], available: false },
    'moloni' => { markets: %w[PT], roles: %w[invoicing], available: false },
    'easypay' => { markets: %w[PT], roles: %w[payment], available: false }
  }.freeze

  def self.available_for_market?(provider, market)
    definition = PROVIDERS[provider]
    definition.present? && definition[:available] && definition[:markets].include?(market)
  end

  def self.supports_market?(provider, market)
    PROVIDERS.fetch(provider, {})[:markets]&.include?(market) || false
  end
end
