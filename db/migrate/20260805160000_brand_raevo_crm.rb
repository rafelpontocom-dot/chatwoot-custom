class BrandRaevoCrm < ActiveRecord::Migration[7.1]
  BRANDING = {
    'INSTALLATION_NAME' => 'RAEVO CRM',
    'BRAND_NAME' => 'RAEVO CRM',
    'LOGO_THUMBNAIL' => '/brand-assets/raevo-logo-thumbnail.svg',
    'LOGO' => '/brand-assets/raevo-logo.svg',
    'LOGO_DARK' => '/brand-assets/raevo-logo.svg',
    'BRAND_URL' => 'https://chatwt.growautomacao.com.br',
    'WIDGET_BRAND_URL' => 'https://chatwt.growautomacao.com.br'
  }.freeze

  def up
    BRANDING.each do |name, value|
      config = InstallationConfig.find_or_initialize_by(name: name)
      config.value = value
      config.locked = false
      config.save!
    end
  end

  def down; end
end
