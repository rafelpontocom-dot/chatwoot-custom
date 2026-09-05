require 'rails_helper'

RSpec.describe RaevoAiIntegration do
  describe 'validations' do
    it 'requires one unique clinic mapping per account' do
      account = create(:account)
      described_class.create!(account: account, clinic_id: 'clinic-one', enabled: true)

      duplicate = described_class.new(account: account, clinic_id: 'clinic-two', enabled: true)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:account_id]).to be_present
    end
  end

  describe 'account features' do
    it 'exposes raevo_ai only while the integration is enabled' do
      account = create(:account)
      integration = described_class.create!(account: account, clinic_id: 'clinic-one', enabled: false)

      expect(account.reload.enabled_features).not_to include('raevo_ai')

      integration.update!(enabled: true)

      expect(account.reload.enabled_features).to include('raevo_ai')
    end
  end
end
