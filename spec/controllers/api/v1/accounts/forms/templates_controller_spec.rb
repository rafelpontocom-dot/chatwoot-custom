require 'rails_helper'

RSpec.describe 'Form templates API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:card) { create(:kanban_card, account: account) }
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

  # A lista de edição leva o schema e as definições inteiras; a de envio não.
  # Ver «gives an agent the forms they can send».
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

  it 'uploads a validated brand logo for a template' do
    template = FormTemplate.create!(
      account: account,
      name: 'Pré-consulta',
      slug: 'pre-consulta-logo',
      category: 'pre_consultation',
      access_classification: 'commercial'
    )

    post "#{templates_path}/#{template.id}/logo",
         headers: administrator.create_new_auth_token,
         params: {
           form_template: {
             brand_logo: fixture_file_upload(Rails.root.join('spec/assets/avatar.png'), 'image/png')
           }
         }

    expect(response).to have_http_status(:success)
    expect(template.reload.brand_logo).to be_attached
    expect(response.parsed_body.fetch('brand_logo_url')).to start_with('/rails/active_storage/blobs/')
  end

  it 'uploads a content image for a template and returns its public form URL' do
    template = FormTemplate.create!(
      account: account,
      name: 'Pré-consulta com imagem',
      slug: 'pre-consulta-com-imagem',
      category: 'pre_consultation',
      access_classification: 'commercial'
    )

    post "#{templates_path}/#{template.id}/content_images",
         headers: administrator.create_new_auth_token,
         params: {
           form_template: {
             content_image: fixture_file_upload(Rails.root.join('spec/assets/avatar.png'), 'image/png')
           }
         }

    expect(response).to have_http_status(:success)
    expect(template.reload.content_images).to be_attached
    expect(response.parsed_body.fetch('url')).to start_with('/rails/active_storage/blobs/')
  end

  it 'removes an uploaded brand logo without changing the template settings' do
    template = FormTemplate.create!(
      account: account,
      name: 'Pré-consulta',
      slug: 'pre-consulta-logo-removivel',
      category: 'pre_consultation',
      access_classification: 'commercial',
      settings: { 'brand_logo_url' => 'https://assets.example.test/logo.svg' }
    )
    template.brand_logo.attach(
      io: StringIO.new('logo'), filename: 'logo.png', content_type: 'image/png'
    )

    delete "#{templates_path}/#{template.id}/logo", headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(template.reload.brand_logo).not_to be_attached
    expect(response.parsed_body.fetch('brand_logo_url')).to be_nil
    expect(template.settings.fetch('brand_logo_url')).to eq('https://assets.example.test/logo.svg')
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

  # Enviar é trabalho de quem atende. O que a secretária continua a não poder é
  # abrir a resposta — ver `FormSubmissionPolicy` e o contexto da oportunidade.
  it 'lets an agent send a form to a contact' do
    template = FormTemplate.create!(
      account: account,
      name: 'Pré-consulta',
      slug: 'pre-consulta-agente',
      category: 'pre_consultation',
      access_classification: 'commercial'
    )
    template.publish!(schema: schema.deep_stringify_keys)
    contact = create(:contact, account: account)
    card.update!(contact: contact)

    post "#{templates_path}/#{template.id}/invitations",
         headers: agent.create_new_auth_token,
         params: { invitation: { contact_id: contact.id, kanban_card_id: card.id } },
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.fetch('token')).to be_present
  end

  it 'gives an agent the forms they can send, and nothing else about them' do
    publicado = FormTemplate.create!(
      account: account,
      name: 'Pré-consulta',
      slug: 'pre-consulta-lista',
      category: 'pre_consultation',
      access_classification: 'commercial'
    )
    publicado.publish!(schema: schema.deep_stringify_keys)
    FormTemplate.create!(
      account: account,
      name: 'Rascunho por publicar',
      slug: 'rascunho',
      category: 'other',
      access_classification: 'commercial'
    )

    get "#{templates_path}/sendable", headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.map { |t| t['name'] }).to eq(['Pré-consulta'])
    expect(response.parsed_body.first.keys).to contain_exactly('id', 'name', 'category', 'access_classification')
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
    card.update!(contact: contact)

    post "#{templates_path}/#{template.id}/invitations",
         headers: administrator.create_new_auth_token,
         params: {
           invitation: {
             contact_id: contact.id,
             kanban_card_id: card.id,
             expires_at: 48.hours.from_now
           }
         },
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
      card.update!(contact: contact)
      post "#{templates_path}/#{template.id}/invitations",
           headers: administrator.create_new_auth_token,
           params: { invitation: { contact_id: contact.id, kanban_card_id: card.id, max_uses: 1 } },
           as: :json

      expect(response).to have_http_status(:created)
      expect(FormInvitation.last).to have_attributes(contact: contact, max_uses: 1)
    end
  end

  private

  def schema
    {
      crm_destination: crm_destination,
      crm_mapping: {
        contact: { name: 'nome', phone_number: 'telefone' }
      },
      sections: [
        {
          key: 'identificacao',
          fields: [
            { key: 'nome', type: 'text', label: 'Nome completo' },
            { key: 'telefone', type: 'phone', label: 'Telefone' }
          ]
        }
      ]
    }
  end

  def crm_destination
    {
      kanban_board_id: card.kanban_board_id,
      kanban_stage_id: card.kanban_stage_id,
      inbox_id: card.inbox_id,
      opportunity_policy: 'reuse_open'
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
