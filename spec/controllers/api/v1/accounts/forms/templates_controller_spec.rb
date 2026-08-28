require 'rails_helper'

RSpec.describe 'Form templates API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:templates_path) { "/api/v1/accounts/#{account.id}/forms/templates" }

  it 'creates a template and publishes an immutable version' do
    post templates_path,
         headers: administrator.create_new_auth_token,
         params: {
           form_template: {
             name: 'Pré-consulta',
             slug: 'pre-consulta',
             category: 'pre_consultation',
             access_classification: 'commercial'
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    template_id = response.parsed_body.fetch('id')

    post "#{templates_path}/#{template_id}/publish",
         headers: administrator.create_new_auth_token,
         params: { form_template: { schema: schema } },
         as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.dig('active_version', 'version_number')).to eq(1)
  end

  it 'prevents an agent from configuring templates' do
    get templates_path, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'lists immutable versions newest first for an administrator' do
    template = FormTemplate.create!(
      account: account,
      name: 'Pré-consulta',
      slug: 'pre-consulta',
      category: 'pre_consultation',
      access_classification: 'commercial'
    )
    template.publish!(schema: schema.deep_stringify_keys)
    template.publish!(schema: schema.deep_stringify_keys)

    get "#{templates_path}/#{template.id}/versions",
        headers: administrator.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.map { |version| version.fetch('version_number') }).to eq([2, 1])
    expect(response.parsed_body.first).to include('published_at')
    expect(response.parsed_body.first).not_to include('schema')
  end

  it 'duplicates a published template as a private reusable copy' do
    template = FormTemplate.create!(
      account: account,
      name: 'Captação',
      slug: 'captacao',
      category: 'lead_capture',
      access_classification: 'commercial',
      public_enabled: true
    )
    template.publish!(schema: schema.deep_stringify_keys)

    post "#{templates_path}/#{template.id}/duplicate",
         headers: administrator.create_new_auth_token,
         params: {
           form_template: { name: 'Captação - cópia', slug: 'captacao-copia' }
         },
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include(
      'name' => 'Captação - cópia',
      'slug' => 'captacao-copia',
      'public_enabled' => false
    )
    expect(response.parsed_body.dig('active_version', 'version_number')).to eq(1)
  end

  it 'issues a single-use invitation without exposing its digest' do
    template = FormTemplate.create!(
      account: account,
      name: 'Pré-consulta',
      slug: 'pre-consulta',
      category: 'pre_consultation',
      access_classification: 'commercial'
    )
    template.publish!(schema: schema.deep_stringify_keys)
    contact = create(:contact, account: account)

    post "#{templates_path}/#{template.id}/invitations",
         headers: administrator.create_new_auth_token,
         params: { invitation: { contact_id: contact.id, expires_at: 48.hours.from_now } },
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.fetch('token')).to match(/\A[a-zA-Z0-9_-]{32,}\z/)
    expect(response.parsed_body).not_to have_key('token_digest')
    expect(FormInvitation.last).to have_attributes(contact: contact, max_uses: 1)
  end

  it 'issues a sensitive-health invitation only for a known contact' do
    with_modified_env 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' => 'forms-test-encryption-key' do
      template = FormTemplate.create!(
        account: account,
        name: 'Anamnese',
        slug: 'anamnese',
        category: 'clinical',
        access_classification: 'sensitive_health'
      )
      template.publish!(schema: clinical_schema)

      post "#{templates_path}/#{template.id}/invitations",
           headers: administrator.create_new_auth_token,
           params: { invitation: { max_uses: 1 } },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)

      contact = create(:contact, account: account)
      post "#{templates_path}/#{template.id}/invitations",
           headers: administrator.create_new_auth_token,
           params: { invitation: { contact_id: contact.id, max_uses: 1 } },
           as: :json

      expect(response).to have_http_status(:created)
      expect(FormInvitation.last).to have_attributes(contact: contact, max_uses: 1)
    end
  end

  private

  def schema
    {
      sections: [
        {
          key: 'identificacao',
          fields: [{ key: 'nome', type: 'text', label: 'Nome completo' }]
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
