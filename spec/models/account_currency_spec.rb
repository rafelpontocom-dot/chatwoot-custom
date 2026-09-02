require 'rails_helper'

RSpec.describe Account do
  let(:account) { create(:account) }

  describe 'currency' do
    it 'accepts a supported currency' do
      account.currency = 'EUR'

      expect(account).to be_valid
      account.save!
      expect(account.reload.currency).to eq('EUR')
    end

    it 'refuses one nobody can format' do
      account.currency = 'XXX'

      expect(account).not_to be_valid
      expect(account.errors[:currency]).to be_present
    end

    it 'stays optional' do
      account.currency = nil

      expect(account).to be_valid
    end
  end
end
