require 'rails_helper'

RSpec.describe Forms::ExpireInvitationsService do
  let(:now) { Time.zone.parse('2026-08-29 13:30:00') }
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:card) { create(:kanban_card, account: account, contact: contact) }
  let(:template) do
    FormTemplate.create!(
      account: account,
      name: 'Orçamento',
      slug: 'orcamento-expirado',
      category: 'lead_capture',
      access_classification: 'commercial'
    )
  end
  let(:version) { template.publish!(schema: schema) }
  let(:invitation) do
    Forms::CreateInvitationService.new(
      account: account,
      form_template_version: version,
      contact: contact,
      kanban_card: card,
      expires_at: now - 1.minute
    ).perform.invitation
  end

  it 'expires a commercial invitation and dispatches one sanitized event' do
    invitation

    expect(Rails.configuration.dispatcher).to receive(:dispatch) do |event_name, timestamp, data|
      expect(event_name).to eq(Events::Types::FORMS_INVITATION_EXPIRED)
      expect(timestamp).to eq(now)
      expect(data).to include(
        account_id: account.id,
        board_id: card.kanban_board_id,
        card_id: card.id,
        form_invitation_id: invitation.id,
        form_template_id: template.id,
        event_key: "forms-invitation:#{invitation.id}:expired"
      )
      expect(data).not_to have_key(:token)
      expect(data).not_to have_key(:answers)
    end

    described_class.new(now: now).perform!

    expect(invitation.reload).to be_expired
  end

  it 'does not publish an expiration event for an anamnese invitation' do
    with_modified_env 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' => 'forms-test-encryption-key' do
      clinical_template = FormTemplate.create!(
        account: account,
        name: 'Anamnese expirada',
        slug: 'anamnese-expirada',
        category: 'clinical',
        access_classification: 'sensitive_health'
      )
      clinical_version = clinical_template.publish!(schema: clinical_schema)
      clinical_invitation = Forms::CreateInvitationService.new(
        account: account,
        form_template_version: clinical_version,
        contact: contact,
        kanban_card: card,
        expires_at: now - 1.minute
      ).perform.invitation

      expect(Rails.configuration.dispatcher).not_to receive(:dispatch)

      described_class.new(now: now).perform!

      expect(clinical_invitation.reload).to be_expired
    end
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

  def clinical_schema
    {
      'sections' => [
        {
          'key' => 'saude',
          'fields' => [
            { 'key' => 'alergias', 'type' => 'textarea', 'label' => 'Alergias', 'required' => true },
            { 'key' => 'consentimento', 'type' => 'consent', 'label' => 'Autorizo', 'required' => true }
          ]
        }
      ]
    }
  end
end
