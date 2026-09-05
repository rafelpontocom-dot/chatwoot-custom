class AddPageTokensToMarketingProviderConnections < ActiveRecord::Migration[7.1]
  def change
    add_column :marketing_provider_connections, :page_tokens, :text
  end
end
