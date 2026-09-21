require 'rails_helper'

RSpec.describe RaevoAi::HandoffConfigurator do
  let(:account) { create(:account) }
  let(:integration) { RaevoAiIntegration.create!(account: account, clinic_id: 'clinic-demo', enabled: true, settings: { 'existing' => true }) }
  let(:team) { create(:team, account: account) }
  let(:inbox) { create(:inbox, account: account) }

  it 'stores a validated team destination without replacing unrelated settings' do
    described_class.new(integration: integration).configure!(
      team_id: team.id, assignee_id: nil, allowed_inbox_ids: [inbox.id], labels: 'intervencao-humana, atendimento-clinica'
    )

    expect(integration.reload.settings).to include('existing' => true)
    expect(integration.settings.fetch('handoff')).to eq(
      'team_id' => team.id, 'assignee_id' => nil, 'allowed_inbox_ids' => [inbox.id],
      'labels' => %w[intervencao-humana atendimento-clinica]
    )
  end

  it 'rejects more than one destination and preserves the previous configuration' do
    agent = create(:user)
    create(:account_user, account: account, user: agent)
    original_settings = integration.settings.deep_dup

    expect do
      described_class.new(integration: integration).configure!(
        team_id: team.id, assignee_id: agent.id, allowed_inbox_ids: [inbox.id], labels: ['intervencao-humana']
      )
    end.to raise_error(described_class::InvalidConfiguration, /exactly one destination/)
    expect(integration.reload.settings).to eq(original_settings)
  end

  it 'rejects inboxes that do not belong to the integration account' do
    other_inbox = create(:inbox)

    expect do
      described_class.new(integration: integration).configure!(
        team_id: team.id, assignee_id: nil, allowed_inbox_ids: [other_inbox.id], labels: ['intervencao-humana']
      )
    end.to raise_error(described_class::InvalidConfiguration, /inboxes/)
  end
end
