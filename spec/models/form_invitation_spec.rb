require 'rails_helper'

RSpec.describe FormInvitation do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:card) { create(:kanban_card, account: account, contact: contact) }
  let(:template) do
    FormTemplate.create!(
      account: account,
      name: 'Pré-consulta',
      slug: 'pre-consulta',
      category: 'pre_consultation',
      access_classification: 'commercial'
    )
  end
  let(:version) { template.publish!(schema: schema) }

  it 'issues an opaque token without storing the raw token' do
    result = Forms::CreateInvitationService.new(
      account: account,
      form_template_version: version,
      contact: contact,
      kanban_card: card
    ).perform
    invitation = result.invitation
    token = result.token

    expect(token).to match(/\A[a-zA-Z0-9_-]{32,}\z/)
    expect(invitation.token_digest).not_to eq(token)
    expect(described_class.find_available_by_token(token)).to eq(invitation)
  end

  it 'consumes a single-use invitation only once' do
    result = Forms::CreateInvitationService.new(
      account: account,
      form_template_version: version,
      contact: contact,
      kanban_card: card,
      max_uses: 1
    ).perform
    invitation = result.invitation
    token = result.token

    invitation.consume!

    expect(invitation).to be_consumed
    expect(invitation.uses_count).to eq(1)
    expect(described_class.find_available_by_token(token)).to be_nil
    expect { invitation.consume! }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'does not resolve an expired invitation' do
    result = Forms::CreateInvitationService.new(
      account: account,
      form_template_version: version,
      contact: contact,
      kanban_card: card,
      expires_at: 1.minute.ago
    ).perform

    draft = FormInvitationDraft.create!(
      account: account,
      form_invitation: result.invitation,
      answers: { 'nome' => 'Pedro Raevo' }
    )

    expect(described_class.find_available_by_token(result.token)).to be_nil
    expect(result.invitation.reload).to be_expired
    expect(result.invitation.admin_payload[:status]).to eq('expired')
    expect { draft.reload }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it 'revokes an available invitation and keeps it unavailable' do
    result = Forms::CreateInvitationService.new(
      account: account,
      form_template_version: version,
      contact: contact,
      kanban_card: card
    ).perform

    draft = FormInvitationDraft.create!(
      account: account,
      form_invitation: result.invitation,
      answers: { 'nome' => 'Pedro Raevo' }
    )

    result.invitation.revoke!

    expect(result.invitation).to be_revoked
    expect(described_class.find_available_by_token(result.token)).to be_nil
    expect { draft.reload }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it 'returns safe invitation audit dates in the administrative payload' do
    result = Forms::CreateInvitationService.new(
      account: account,
      form_template_version: version,
      contact: contact,
      kanban_card: card,
      expires_at: 2.days.from_now
    ).perform

    result.invitation.consume!

    expect(result.invitation.admin_payload).to include(
      created_at: result.invitation.created_at,
      expires_at: result.invitation.expires_at,
      completed_at: result.invitation.completed_at
    )
  end

  it 'does not replace a consumed invitation status when revoking' do
    result = Forms::CreateInvitationService.new(
      account: account,
      form_template_version: version,
      contact: contact,
      kanban_card: card
    ).perform
    result.invitation.consume!

    expect { result.invitation.revoke! }.to raise_error(ActiveRecord::RecordInvalid)
    expect(result.invitation.reload).to be_consumed
  end

  it 'requires contact and opportunity context for a commercial invitation' do
    invitation = described_class.new(
      account: account,
      form_template_version: version,
      max_uses: 1,
      token_digest: described_class.digest_token('commercial-without-context')
    )

    expect(invitation).not_to be_valid
    expect(invitation.errors[:contact]).to include('must be present for individual forms')
    expect(invitation.errors[:kanban_card]).to include('must be present for individual forms')
  end

  it 'rejects a contact that does not match the linked opportunity' do
    card = create(:kanban_card, account: account)
    other_contact = create(:contact, account: account)

    invitation = described_class.new(
      account: account,
      form_template_version: version,
      contact: other_contact,
      kanban_card: card,
      max_uses: 1,
      token_digest: described_class.digest_token('different-contact')
    )

    expect(invitation).not_to be_valid
    expect(invitation.errors[:base]).to include('Invitation contact must match the linked opportunity')
  end

  it 'requires a single-use invitation for an anamnese' do
    with_modified_env 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' => 'forms-test-encryption-key' do
      clinical_template = FormTemplate.create!(
        account: account,
        name: 'Anamnese inicial',
        slug: 'anamnese-inicial',
        category: 'clinical',
        access_classification: 'sensitive_health'
      )
      clinical_version = clinical_template.publish!(schema: clinical_schema)
      invitation = described_class.new(
        account: account,
        form_template_version: clinical_version,
        contact: contact,
        kanban_card: card,
        max_uses: 2,
        token_digest: described_class.digest_token('clinical-multiple-use')
      )

      expect(invitation).not_to be_valid
      expect(invitation.errors[:max_uses]).to include('must be one for sensitive health forms')
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
      'sections' => [
        {
          'key' => 'identificacao',
          'fields' => [{ 'key' => 'nome', 'type' => 'text', 'label' => 'Nome completo' }]
        }
      ]
    }
  end

  def clinical_schema
    {
      'sections' => [
        {
          'key' => 'saude',
          'fields' => [
            { 'key' => 'alergias', 'type' => 'textarea', 'label' => 'Alergias', 'required' => true },
            { 'key' => 'consentimento_clinico', 'type' => 'consent', 'label' => 'Autorizo', 'required' => true }
          ]
        }
      ]
    }
  end
end
