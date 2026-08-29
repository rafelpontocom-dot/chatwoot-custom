require 'rails_helper'

RSpec.describe FormInvitationDraft do
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
  let(:invitation) do
    Forms::CreateInvitationService.new(
      account: account,
      form_template_version: version,
      contact: contact,
      kanban_card: card
    ).perform.invitation
  end

  it 'persists only published non-attachment answers for commercial forms' do
    draft = described_class.new(account: account, form_invitation: invitation)

    draft.assign_answers(
      nome: 'Pedro Raevo',
      oculto: 'nao deve salvar',
      desconhecido: 'nao deve salvar'
    )
    draft.save!

    expect(draft.answers).to eq('nome' => 'Pedro Raevo')
    expect(draft.sensitive_answers_ciphertext).to be_nil
    expect(draft.public_payload).to include(answers: { 'nome' => 'Pedro Raevo' })
  end

  it 'keeps the saved section within the published form bounds' do
    draft = described_class.new(account: account, form_invitation: invitation)

    draft.assign_current_section_index(99)
    draft.save!

    expect(draft.current_section_index).to be_zero
  end

  it 'encrypts clinical draft answers and exposes them only through the invitation payload' do
    with_modified_env 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' => 'forms-test-encryption-key' do
      clinical_template = FormTemplate.create!(
        account: account,
        name: 'Anamnese',
        slug: 'anamnese',
        category: 'clinical',
        access_classification: 'sensitive_health'
      )
      clinical_version = clinical_template.publish!(schema: clinical_schema)
      clinical_invitation = Forms::CreateInvitationService.new(
        account: account,
        form_template_version: clinical_version,
        contact: contact,
        kanban_card: card
      ).perform.invitation
      draft = described_class.new(account: account, form_invitation: clinical_invitation)

      draft.assign_answers(nome: 'Pedro Raevo', documento: 'nao deve salvar')
      draft.save!

      expect(draft.answers).to eq({})
      expect(draft.sensitive_answers_ciphertext).to start_with('v1:')
      expect(draft.sensitive_answers_ciphertext).not_to include('Pedro Raevo')
      expect(draft.public_payload).to include(answers: { 'nome' => 'Pedro Raevo' })
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
          'fields' => [
            { 'key' => 'nome', 'type' => 'text', 'label' => 'Nome' },
            { 'key' => 'oculto', 'type' => 'hidden', 'label' => 'Oculto' }
          ]
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
            { 'key' => 'nome', 'type' => 'text', 'label' => 'Nome' },
            { 'key' => 'documento', 'type' => 'attachment', 'label' => 'Documento' },
            {
              'key' => 'consentimento',
              'type' => 'consent',
              'label' => 'Autorizo o tratamento dos dados de saúde',
              'required' => true
            }
          ]
        }
      ]
    }
  end
end
