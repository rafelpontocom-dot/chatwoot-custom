require 'rails_helper'

RSpec.describe FormInvitation do
  let(:account) { create(:account) }
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
    result = Forms::CreateInvitationService.new(account: account, form_template_version: version).perform
    invitation = result.invitation
    token = result.token

    expect(token).to match(/\A[a-zA-Z0-9_-]{32,}\z/)
    expect(invitation.token_digest).not_to eq(token)
    expect(described_class.find_available_by_token(token)).to eq(invitation)
  end

  it 'consumes a single-use invitation only once' do
    result = Forms::CreateInvitationService.new(account: account, form_template_version: version, max_uses: 1).perform
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
      expires_at: 1.minute.ago
    ).perform

    expect(described_class.find_available_by_token(result.token)).to be_nil
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
        contact: create(:contact, account: account),
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
