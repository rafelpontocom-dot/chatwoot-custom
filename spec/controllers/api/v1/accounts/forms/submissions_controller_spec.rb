require 'rails_helper'

RSpec.describe 'Form submissions API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account, name: 'Pedro Raevo') }
  let(:template) do
    FormTemplate.create!(
      account: account,
      name: 'Pré-consulta',
      slug: 'pre-consulta',
      category: 'pre_consultation',
      access_classification: 'commercial'
    )
  end
  let(:submission) do
    version = template.publish!(schema: schema)
    invitation = Forms::CreateInvitationService.new(
      account: account,
      form_template_version: version,
      contact: contact
    ).perform.invitation

    Forms::SubmitPublicFormService.new(invitation: invitation, answers: { 'nome' => 'Pedro Raevo' }).perform!
  end
  let(:submissions_path) { "/api/v1/accounts/#{account.id}/forms/submissions" }

  it 'lists safe submission summaries and exposes answers only in the authorized detail' do
    submission

    get submissions_path, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      include('id' => submission.id, 'form_name' => 'Pré-consulta', 'contact' => include('id' => contact.id))
    )
    expect(response.parsed_body.first).not_to have_key('answers')

    get "#{submissions_path}/#{submission.id}", headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'id' => submission.id,
      'answers' => include('nome' => 'Pedro Raevo'),
      'fields' => include('key' => 'nome', 'label' => 'Nome', 'type' => 'text')
    )
  end

  it 'records a clinical read and returns decrypted answers only in authorized detail' do
    with_modified_env 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' => 'forms-test-encryption-key' do
      clinical_template = FormTemplate.create!(
        account: account,
        name: 'Anamnese inicial',
        slug: 'anamnese-inicial',
        category: 'clinical',
        access_classification: 'sensitive_health'
      )
      version = clinical_template.publish!(schema: clinical_schema)
      invitation = Forms::CreateInvitationService.new(
        account: account,
        form_template_version: version,
        contact: contact
      ).perform.invitation
      clinical_submission = Forms::SubmitPublicFormService.new(
        invitation: invitation,
        answers: { 'alergias' => 'Penicilina', 'consentimento_clinico' => true }
      ).perform!

      expect do
        get "#{submissions_path}/#{clinical_submission.id}", headers: administrator.create_new_auth_token, as: :json
      end.to change(FormAccessAudit, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.dig('answers', 'alergias')).to eq('Penicilina')
      expect(FormAccessAudit.last).to have_attributes(
        account: account,
        form_submission: clinical_submission,
        actor: administrator,
        action: 'view'
      )
    end
  end

  private

  def schema
    {
      'sections' => [
        { 'key' => 'identificacao', 'fields' => [{ 'key' => 'nome', 'type' => 'text', 'label' => 'Nome' }] }
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
            {
              'key' => 'consentimento_clinico',
              'type' => 'consent',
              'label' => 'Autorizo o tratamento dos dados de saúde para atendimento',
              'required' => true
            }
          ]
        }
      ]
    }
  end
end
