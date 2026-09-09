require 'rails_helper'

RSpec.describe RaevoAi::CrmContactNameExecutor do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, name: current_name) }
  let(:integration) do
    RaevoAiIntegration.create!(
      account: account,
      clinic_id: 'clinic-demo',
      enabled: true,
      settings: { 'crm' => { 'contact_name' => { 'overwrite' => 'if_empty' } } }
    )
  end

  def execute(name:, action_id: 'turn-100:contact-name')
    described_class.new(
      integration: integration,
      contact: contact,
      command: { action_id: action_id, name: name }
    ).perform
  end

  context 'when an automated ingress persisted a conversational placeholder' do
    let(:current_name) { 'Oi' }

    it 'replaces the placeholder with an explicitly confirmed human name' do
      result = execute(name: 'Pedro Raphael')

      expect(contact.reload.name).to eq('Pedro Raphael')
      expect(result.dig('receipts', 'contact_name', 'status')).to eq('applied')
    end
  end

  context 'when a human-readable name already exists' do
    let(:current_name) { 'Nome editado pela equipe' }

    it 'preserves the human edit under the if_empty policy' do
      result = execute(name: 'Outro Nome')

      expect(contact.reload.name).to eq('Nome editado pela equipe')
      expect(result.dig('receipts', 'contact_name', 'status')).to eq('skipped')
    end
  end

  context 'when the proposed name is not a credible identity' do
    let(:current_name) { '' }

    it 'rejects a greeting before it reaches the contact' do
      expect { execute(name: 'Oi') }.to raise_error(described_class::InvalidContact)
      expect(contact.reload.name).to be_blank
    end
  end
end
