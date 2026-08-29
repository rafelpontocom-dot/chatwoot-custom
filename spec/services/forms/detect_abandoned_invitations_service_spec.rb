require 'rails_helper'

RSpec.describe Forms::DetectAbandonedInvitationsService do
  let(:now) { Time.zone.parse('2026-08-29 15:00:00') }
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:card) { create(:kanban_card, account: account, contact: contact) }
  let(:template) do
    FormTemplate.create!(
      account: account,
      name: 'Orçamento',
      slug: 'orcamento-abandonado',
      category: 'lead_capture',
      access_classification: 'commercial',
      settings: { 'abandonment_delay_hours' => 24 }
    )
  end
  let(:version) { template.publish!(schema: schema) }
  let(:invitation) do
    Forms::CreateInvitationService.new(
      account: account,
      form_template_version: version,
      contact: contact,
      kanban_card: card
    ).perform.invitation
  end

  it 'dispatches one safe event after a sent invitation remains unopened past its configured delay' do
    invitation.update!(sent_at: now - 25.hours)

    expect(Rails.configuration.dispatcher).to receive(:dispatch) do |event_name, timestamp, data|
      expect(event_name).to eq(Events::Types::FORMS_INVITATION_ABANDONED)
      expect(timestamp).to eq(now)
      expect(data).to include(
        account_id: account.id,
        board_id: card.kanban_board_id,
        card_id: card.id,
        form_invitation_id: invitation.id,
        form_template_id: template.id,
        event_key: "forms-invitation:#{invitation.id}:abandoned"
      )
      expect(data).not_to have_key(:token)
      expect(data).not_to have_key(:answers)
    end

    described_class.new(now: now).perform!

    expect(invitation.reload.abandoned_at).to eq(now)
  end

  it 'does not mark invitations that were opened, completed, or have no configured abandonment rule' do
    invitation.update!(sent_at: now - 25.hours, opened_at: now - 1.hour)
    unconfigured_template = FormTemplate.create!(
      account: account,
      name: 'Sem aviso',
      slug: 'sem-aviso-abandono',
      category: 'lead_capture',
      access_classification: 'commercial'
    )
    unconfigured_invitation = Forms::CreateInvitationService.new(
      account: account,
      form_template_version: unconfigured_template.publish!(schema: schema),
      contact: contact,
      kanban_card: card
    ).perform.invitation
    unconfigured_invitation.update!(sent_at: now - 48.hours)

    expect(Rails.configuration.dispatcher).not_to receive(:dispatch)

    described_class.new(now: now).perform!

    expect(invitation.reload.abandoned_at).to be_nil
    expect(unconfigured_invitation.reload.abandoned_at).to be_nil
  end

  private

  def schema
    {
      'crm_destination' => {
        'kanban_board_id' => card.kanban_board_id,
        'kanban_stage_id' => card.kanban_stage_id,
        'inbox_id' => card.inbox_id,
        'opportunity_policy' => 'reuse_open'
      },
      'sections' => [{ 'key' => 'dados', 'fields' => [{ 'key' => 'nome', 'type' => 'text', 'label' => 'Nome' }] }]
    }
  end
end
