require 'rails_helper'

RSpec.describe 'Public form templates API', type: :request do
  let(:account) { create(:account) }
  let(:template) do
    FormTemplate.create!(
      account: account,
      name: 'Quero saber mais',
      slug: 'quero-saber-mais',
      category: 'lead_capture',
      access_classification: 'commercial',
      public_enabled: true,
      public_token: 'captacao-raevo-publica'
    )
  end
  let(:version) { template.publish!(schema: schema) }
  let(:public_path) { "/formularios/#{template.public_token}" }

  it 'opens a published public form and creates a contact from declared mappings' do
    version

    get public_path, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('form' => include('name' => 'Quero saber mais'))
    expect(response.parsed_body.to_s).not_to include('crm_mapping')

    post "#{public_path}/respostas",
         params: {
           submission: {
             answers: { nome: 'Pedro Raevo', email: 'pedro@raevo.io', aceite: true }
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    expect(FormSubmission.last).to have_attributes(account: account, form_template_version: version)
    expect(FormSubmission.last.contact).to have_attributes(name: 'Pedro Raevo', email: 'pedro@raevo.io')
  end

  it 'updates only the declared contact fields when the public link identifies an existing contact' do
    contact = create(:contact, account: account, name: 'Nome anterior', email: 'pedro@raevo.io')
    version

    post "#{public_path}/respostas",
         params: {
           submission: {
             answers: { nome: 'Pedro Raevo', email: contact.email, origem: 'Google', aceite: true }
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    expect(FormSubmission.last.contact).to eq(contact)
    expect(contact.reload).to have_attributes(name: 'Pedro Raevo')
    expect(contact.custom_attributes).to include('origem' => 'Google')
  end

  it 'does not expose a sensitive-health form through a general public link' do
    template.update!(public_enabled: false, access_classification: 'sensitive_health')

    get public_path, as: :json

    expect(response).to have_http_status(:not_found)
  end

  it 'exposes only the approved public appearance settings' do
    template.update!(settings: {
                       'brand_name' => 'Clínica Raevo',
                       'theme' => 'warm',
                       'internal_note' => 'never expose this'
                     })
    version

    get public_path, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['form']).to include(
      'brand_name' => 'Clínica Raevo',
      'theme' => 'warm'
    )
    expect(response.parsed_body.to_s).not_to include('internal_note')
  end

  private

  def schema
    {
      'crm_mapping' => { 'contact' => contact_mapping },
      'sections' => [
        {
          'key' => 'identificacao',
          'fields' => [
            { 'key' => 'nome', 'type' => 'text', 'label' => 'Nome', 'required' => true },
            { 'key' => 'email', 'type' => 'email', 'label' => 'E-mail', 'required' => true },
            { 'key' => 'origem', 'type' => 'text', 'label' => 'Origem' },
            { 'key' => 'aceite', 'type' => 'consent', 'label' => 'Li e aceito', 'required' => true }
          ]
        }
      ]
    }
  end

  def contact_mapping
    {
      'name' => 'nome',
      'email' => 'email',
      'custom_attributes' => { 'origem' => 'origem' }
    }
  end
end
