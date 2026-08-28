require 'rails_helper'

RSpec.describe 'Public forms API', type: :request do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, name: 'Pedro Raevo') }
  let(:template) do
    FormTemplate.create!(
      account: account,
      name: 'Pré-consulta',
      slug: 'pre-consulta',
      category: 'pre_consultation',
      access_classification: 'commercial',
      settings: { 'locale' => 'pt-BR', 'description' => 'Conte-nos um pouco antes da consulta.' }
    )
  end
  let(:version) { template.publish!(schema: schema) }
  let(:invitation_result) do
    Forms::CreateInvitationService.new(
      account: account,
      form_template_version: version,
      contact: contact
    ).perform
  end

  it 'shows the published form without exposing the invite context' do
    get "/formularios/convites/#{invitation_result.token}", as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'form' => include(
        'name' => 'Pré-consulta',
        'locale' => 'pt-BR',
        'description' => 'Conte-nos um pouco antes da consulta.'
      )
    )
    expect(response.parsed_body.to_s).not_to include(contact.id.to_s)
    expect(response.parsed_body.to_s).not_to include('crm_mapping')
  end

  it 'renders the public form shell for a valid invitation' do
    get "/formularios/convites/#{invitation_result.token}"

    expect(response).to have_http_status(:success)
    expect(response.body).to include('id="public-form-app"')
  end

  it 'renders a sensitive-health form only through its individual invitation' do
    with_modified_env 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' => 'forms-test-encryption-key' do
      clinical_template = FormTemplate.create!(
        account: account,
        name: 'Anamnese inicial',
        slug: 'anamnese-inicial',
        category: 'clinical',
        access_classification: 'sensitive_health'
      )
      clinical_version = clinical_template.publish!(schema: clinical_schema)
      invitation = Forms::CreateInvitationService.new(
        account: account,
        form_template_version: clinical_version,
        contact: contact
      ).perform

      get "/formularios/convites/#{invitation.token}", as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.dig('form', 'name')).to eq('Anamnese inicial')
      expect(response.parsed_body.to_s).not_to include(contact.id.to_s)
    end
  end

  it 'renders the immutable version selected by the invitation' do
    invitation_result
    template.publish!(
      schema: {
        'sections' => [
          {
            'key' => 'nova_etapa',
            'fields' => [{ 'key' => 'nova_pergunta', 'type' => 'text', 'label' => 'Nova pergunta' }]
          }
        ]
      }
    )

    get "/formularios/convites/#{invitation_result.token}", as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('version' => version.version_number)
    expect(response.parsed_body.dig('schema', 'sections', 0, 'fields')).to include(
      include('key' => 'nome_completo')
    )
  end

  it 'submits answers once through an available invite' do
    post "/formularios/convites/#{invitation_result.token}/respostas",
         params: { submission: { answers: { nome_completo: 'Pedro Raevo', aceite_privacidade: true } } },
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include('status' => 'submitted')
    expect(FormSubmission.last).to have_attributes(contact: contact, form_template_version: version)
    expect(invitation_result.invitation.reload).to be_consumed
  end

  it 'does not reveal a consumed invitation' do
    invitation_result.invitation.consume!

    get "/formularios/convites/#{invitation_result.token}", as: :json

    expect(response).to have_http_status(:not_found)
  end

  it 'limits repeated submissions from the same address' do
    allow(Rails.cache).to receive(:increment).and_return(11)

    post "/formularios/convites/#{invitation_result.token}/respostas",
         params: { submission: { answers: { nome_completo: 'Pedro Raevo', aceite_privacidade: true } } },
         as: :json

    expect(response).to have_http_status(:too_many_requests)
    expect(FormSubmission.count).to be_zero
  end

  it 'rejects a submission that fills the honeypot field' do
    post "/formularios/convites/#{invitation_result.token}/respostas",
         params: {
           submission: {
             website: 'https://spam.example',
             answers: { nome_completo: 'Pedro Raevo', aceite_privacidade: true }
           }
         },
         as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(FormSubmission).not_to exist
  end

  private

  def schema
    {
      'crm_mapping' => { 'contact' => { 'email' => 'email' } },
      'sections' => [
        {
          'key' => 'identificacao',
          'title' => 'Identificação',
          'fields' => [
            { 'key' => 'nome_completo', 'type' => 'text', 'label' => 'Nome completo', 'required' => true },
            { 'key' => 'aceite_privacidade', 'type' => 'consent', 'label' => 'Li e aceito', 'required' => true }
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
