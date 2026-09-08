require 'rails_helper'

RSpec.describe RaevoAi::FinanceCatalogPublisher do
  let(:account) { create(:account) }
  let(:board) { create(:kanban_board, account: account) }
  let(:connection) do
    FinanceModuleSetting.create!(account: account, market: 'BR', enabled: true)
    FinanceProviderConnection.create!(
      account: account, provider: 'asaas', environment: 'sandbox', status: 'connected', api_key: 'sandbox-key'
    )
  end
  let(:integration) do
    RaevoAiIntegration.create!(
      account: account,
      clinic_id: 'clinic-demo',
      enabled: false,
      settings: { 'crm' => { 'boards' => { 'captacao' => { 'board_id' => board.id } } } }
    )
  end

  it 'publishes an Asaas charge by semantic key without storing a credential' do
    result = described_class.new(integration: integration).publish!(
      charge_key: 'private_consultation_deposit',
      board_key: 'captacao',
      provider_connection_id: connection.id,
      amount_cents: 20_000,
      billing_type: 'undefined',
      currency: 'BRL',
      due_in_days: 1,
      description: 'Sinal de consulta particular',
      tax_id_source: 'command'
    )

    expect(result).to include(
      'charge_key' => 'private_consultation_deposit',
      'provider' => 'asaas',
      'environment' => 'sandbox'
    )
    expect(integration.reload.settings.dig('finance', 'charges', 'private_consultation_deposit')).to include(
      'board_key' => 'captacao',
      'provider_connection_id' => connection.id,
      'amount_cents' => 20_000,
      'tax_id_source' => 'command'
    )
    expect(integration.settings.to_json).not_to include('sandbox-key')
  end

  it 'fails closed for a board that is not in the CRM catalog' do
    expect do
      described_class.new(integration: integration).publish!(
        charge_key: 'private_consultation_deposit', board_key: 'tratamento',
        provider_connection_id: connection.id, amount_cents: 20_000,
        billing_type: 'undefined', currency: 'BRL', due_in_days: 1,
        tax_id_source: 'command'
      )
    end.to raise_error(described_class::InvalidCatalog, /board/)
  end

  it 'requires the integration to be inactive during publication' do
    integration.update!(enabled: true)
    expect do
      described_class.new(integration: integration).publish!(
        charge_key: 'private_consultation_deposit', board_key: 'captacao',
        provider_connection_id: connection.id, amount_cents: 20_000,
        billing_type: 'undefined', currency: 'BRL', due_in_days: 1,
        tax_id_source: 'command'
      )
    end.to raise_error(described_class::InvalidCatalog, /inactive/)
  end
end
