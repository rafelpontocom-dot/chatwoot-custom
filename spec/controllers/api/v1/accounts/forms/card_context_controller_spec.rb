require 'rails_helper'

RSpec.describe 'Form card context API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account, name: 'Pedro Raevo') }
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
  let(:path) { "/api/v1/accounts/#{account.id}/forms/kanban_cards/#{card.id}" }

  it 'lists safe invitation and submission summaries for an opportunity' do
    invitation = Forms::CreateInvitationService.new(
      account: account,
      form_template_version: version,
      contact: contact,
      kanban_card: card
    ).perform.invitation
    submission = FormSubmission.create!(
      account: account,
      form_template_version: version,
      form_invitation: invitation,
      contact: contact,
      kanban_card: card,
      answers: { 'nome' => 'Pedro Raevo' },
      metadata: {},
      submitted_at: Time.current
    )

    get path, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'invitations' => include(include('id' => invitation.id, 'form_name' => 'Pré-consulta')),
      'submissions' => include(include('id' => submission.id, 'form_name' => 'Pré-consulta'))
    )
    expect(response.parsed_body.to_s).not_to include('token_digest')
    expect(response.parsed_body.to_s).not_to include('answers')
  end

  it 'lets an agent see a clinical answer exists without letting them read it' do
    agent = create(:user, account: account, role: :agent)
    # Sem acesso à caixa de entrada, o agente nem o cartão vê — a aba de
    # formulários não é maneira de contornar isso.
    create(:inbox_member, user: agent, inbox: card.inbox)
    clinical = FormTemplate.create!(
      account: account,
      name: 'Inquérito Pré-Consulta de Obesidade',
      slug: 'anamnese-obesidade',
      category: 'clinical',
      access_classification: 'sensitive_health'
    )
    submission = nil
    with_modified_env 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' => 'forms-test-encryption-key' do
      clinical_version = clinical.publish!(schema: clinical_schema)
      submission = FormSubmission.create_from_answers!(
        account: account,
        form_template_version: clinical_version,
        contact: contact,
        kanban_card: card,
        answers: { 'aceito' => true }
      )
    end

    get path, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    resposta = response.parsed_body['submissions'].first
    expect(resposta).to include('id' => submission.id, 'restricted' => true)
    # O nome fica — foi ele que a secretária escolheu ao enviar. O conteúdo não.
    expect(resposta['form_name']).to eq('Inquérito Pré-Consulta de Obesidade')
    expect(resposta).not_to have_key('answers')
    expect(response.parsed_body.to_s).not_to include('aceito')
  end

  it 'keeps answers of the person separate from answers of this opportunity' do
    outro_card = create(:kanban_card, account: account, contact: contact)
    template.update!(settings: { 'store_on_contact' => true })
    da_pessoa = FormSubmission.create!(
      account: account,
      form_template_version: version,
      contact: contact,
      kanban_card: outro_card,
      answers: { 'nome' => 'Pedro Raevo' },
      metadata: {},
      submitted_at: Time.current
    )

    get path, headers: administrator.create_new_auth_token, as: :json

    expect(response.parsed_body['submissions']).to be_empty
    expect(response.parsed_body['contact_submissions']).to include(include('id' => da_pessoa.id))
  end

  it 'leaves an opportunity-scoped answer out of the contact section' do
    outro_card = create(:kanban_card, account: account, contact: contact)
    FormSubmission.create!(
      account: account,
      form_template_version: version,
      contact: contact,
      kanban_card: outro_card,
      answers: { 'nome' => 'Pedro Raevo' },
      metadata: {},
      submitted_at: Time.current
    )

    get path, headers: administrator.create_new_auth_token, as: :json

    expect(response.parsed_body['contact_submissions']).to be_empty
  end

  private

  def clinical_schema
    {
      'sections' => [
        { 'key' => 'consentimento',
          'fields' => [{ 'key' => 'aceito', 'type' => 'consent', 'label' => 'Aceito', 'required' => true }] }
      ]
    }
  end

  def schema
    {
      'crm_destination' => {
        'kanban_board_id' => card.kanban_board_id,
        'kanban_stage_id' => card.kanban_stage_id,
        'inbox_id' => card.inbox_id,
        'opportunity_policy' => 'reuse_open'
      },
      'sections' => [
        { 'key' => 'identificacao', 'fields' => [{ 'key' => 'nome', 'type' => 'text', 'label' => 'Nome' }] }
      ]
    }
  end
end
