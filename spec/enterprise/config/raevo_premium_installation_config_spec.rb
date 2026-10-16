require 'rails_helper'

# Fica em spec/enterprise porque o CI apaga enterprise/ antes da suite FOSS; corre
# no passo «Raevo specs that need the enterprise code» de custom_checks.yml.
RSpec.describe 'Raevo premium installation config' do # rubocop:disable RSpec/DescribeClass
  it 'brands the installation as RAEVO CRM' do
    config = YAML.safe_load(Rails.root.join('enterprise/config/premium_installation_config.yml').read)
    values = config.to_h { |item| [item['name'], item['value']] }

    expect(values).to include('INSTALLATION_NAME' => 'RAEVO CRM', 'BRAND_URL' => 'https://crm.raevo.io',
                              'LOGO' => '/brand-assets/raevo-logo.svg')
  end
end
