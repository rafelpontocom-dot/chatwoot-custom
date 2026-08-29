require 'rails_helper'

RSpec.describe Forms::MarkInvitationSentService do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:card) { create(:kanban_card, :conversation_origin, conversation: conversation) }
  let(:contact) { card.contact }
  let(:template) do
    FormTemplate.create!(
      account: account,
      name: 'Pré-consulta',
      slug: 'pre-consulta-enviada',
      category: 'pre_consultation',
      access_classification: 'commercial'
    )
  end
  let(:version) { template.publish!(schema: schema) }
  let(:invitation_result) do
    Forms::CreateInvitationService.new(
      account: account,
      form_template_version: version,
      contact: contact,
      kanban_card: card
    ).perform
  end

  it 'records a commercial invitation only after its link is sent in the linked conversation' do
    invitation_result
    message = create(
      :message,
      account: account,
      conversation: conversation,
      inbox: conversation.inbox,
      message_type: :outgoing,
      content: "Responda por aqui: https://crm.raevo.io/formularios/convites/#{invitation_result.token}"
    )

    expect(Rails.configuration.dispatcher).to receive(:dispatch) do |event_name, _timestamp, data|
      expect(event_name).to eq(Events::Types::FORMS_INVITATION_SENT)
      expect(data).to include(
        account_id: account.id,
        board_id: card.kanban_board_id,
        card_id: card.id,
        form_invitation_id: invitation_result.invitation.id,
        form_template_id: template.id,
        event_key: "forms-invitation:#{invitation_result.invitation.id}:sent"
      )
    end

    described_class.new(message: message).perform!

    expect(invitation_result.invitation.reload.sent_at).to be_present
  end

  it 'does not mark a private note or a link sent to another conversation' do
    invitation_result
    other_conversation = create(:conversation, account: account)
    private_message = create(
      :message,
      account: account,
      conversation: conversation,
      inbox: conversation.inbox,
      message_type: :outgoing,
      private: true,
      content: "https://crm.raevo.io/formularios/convites/#{invitation_result.token}"
    )
    other_message = create(
      :message,
      account: account,
      conversation: other_conversation,
      inbox: other_conversation.inbox,
      message_type: :outgoing,
      content: "https://crm.raevo.io/formularios/convites/#{invitation_result.token}"
    )

    expect(Rails.configuration.dispatcher).not_to receive(:dispatch)

    described_class.new(message: private_message).perform!
    described_class.new(message: other_message).perform!

    expect(invitation_result.invitation.reload.sent_at).to be_nil
  end

  it 'does not publish a sent event for an anamnese invitation' do
    with_modified_env 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' => 'forms-test-encryption-key' do
      clinical_template = FormTemplate.create!(
        account: account,
        name: 'Anamnese individual',
        slug: 'anamnese-enviada',
        category: 'clinical',
        access_classification: 'sensitive_health'
      )
      clinical_version = clinical_template.publish!(schema: clinical_schema)
      clinical_invitation = Forms::CreateInvitationService.new(
        account: account,
        form_template_version: clinical_version,
        contact: contact,
        kanban_card: card
      ).perform
      message = create(
        :message,
        account: account,
        conversation: conversation,
        inbox: conversation.inbox,
        message_type: :outgoing,
        content: "https://crm.raevo.io/formularios/convites/#{clinical_invitation.token}"
      )

      expect(Rails.configuration.dispatcher).not_to receive(:dispatch)

      described_class.new(message: message).perform!

      expect(clinical_invitation.invitation.reload.sent_at).to be_present
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
