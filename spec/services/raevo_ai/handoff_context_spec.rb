require 'rails_helper'

RSpec.describe RaevoAi::HandoffContext do
  describe '#payload' do
    it 'builds a tenant-scoped handoff payload from a trusted conversation without exposing a base URL' do
      account = create(:account)
      team = create(:team, account: account)
      conversation = create(:conversation, account: account)
      integration = RaevoAiIntegration.create!(
        account: account,
        clinic_id: 'clinic-demo',
        enabled: true,
        settings: {
          'handoff' => {
            'team_id' => team.id,
            'allowed_inbox_ids' => [conversation.inbox_id],
            'labels' => ['intervencao-humana']
          }
        }
      )

      expect(described_class.new(integration: integration, conversation: conversation).payload).to eq(
        'clinic_id' => 'clinic-demo',
        'account_id' => account.id,
        'conversation_id' => conversation.display_id,
        'contact_id' => conversation.contact_id,
        'handoff_team_id' => team.id,
        'handoff_labels' => ['intervencao-humana']
      )
    end

    it 'rejects a conversation outside the integration account before exposing any identifiers' do
      integration = RaevoAiIntegration.create!(account: create(:account), clinic_id: 'clinic-demo', enabled: true)
      other_conversation = create(:conversation)

      expect do
        described_class.new(integration: integration, conversation: other_conversation).payload
      end.to raise_error(RaevoAi::HandoffContext::UnauthorizedConversation)
    end

    it 'rejects a conversation from an inbox outside the tenant allowlist' do
      account = create(:account)
      team = create(:team, account: account)
      conversation = create(:conversation, account: account)
      integration = RaevoAiIntegration.create!(
        account: account,
        clinic_id: 'clinic-demo',
        enabled: true,
        settings: {
          'handoff' => {
            'team_id' => team.id,
            'allowed_inbox_ids' => [conversation.inbox_id + 1],
            'labels' => ['intervencao-humana']
          }
        }
      )

      expect do
        described_class.new(integration: integration, conversation: conversation).payload
      end.to raise_error(RaevoAi::HandoffContext::IneligibleInbox)
    end

    it 'rejects a handoff team that belongs to another account' do
      account = create(:account)
      other_team = create(:team, account: create(:account))
      conversation = create(:conversation, account: account)
      integration = RaevoAiIntegration.create!(
        account: account,
        clinic_id: 'clinic-demo',
        enabled: true,
        settings: {
          'handoff' => {
            'team_id' => other_team.id,
            'allowed_inbox_ids' => [conversation.inbox_id],
            'labels' => ['intervencao-humana']
          }
        }
      )

      expect do
        described_class.new(integration: integration, conversation: conversation).payload
      end.to raise_error(RaevoAi::HandoffContext::InvalidHandoffConfiguration)
    end
  end
end
