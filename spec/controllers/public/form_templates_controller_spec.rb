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

  it 'normalizes a Brazilian phone number supplied without country code' do
    template.update!(settings: { 'locale' => 'pt_BR' })
    phone_version = template.publish!(schema: phone_schema)

    post "#{public_path}/respostas",
         params: {
           submission: {
             answers: { nome: 'Pedro Raevo', telefone: '(11) 99999-9999' }
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    expect(FormSubmission.last).to have_attributes(form_template_version: phone_version)
    expect(FormSubmission.last.contact).to have_attributes(phone_number: '+5511999999999')
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
                       'brand_logo_url' => 'https://cdn.raevo.io/clinica.svg',
                       'privacy_policy_url' => 'https://clinica.raevo.io/privacidade',
                       'internal_note' => 'never expose this'
                     })
    version

    get public_path, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['form']).to include(
      'brand_name' => 'Clínica Raevo',
      'theme' => 'warm',
      'brand_logo_url' => 'https://cdn.raevo.io/clinica.svg',
      'privacy_policy_url' => 'https://clinica.raevo.io/privacidade'
    )
    expect(response.parsed_body.to_s).not_to include('internal_note')
  end

  it 'prefers an uploaded brand logo over an external appearance URL' do
    template.brand_logo.attach(
      io: File.open(Rails.root.join('spec/assets/avatar.png')),
      filename: 'clinica.png',
      content_type: 'image/png'
    )
    template.update!(settings: { 'brand_logo_url' => 'https://cdn.raevo.io/old-logo.svg' })
    version

    get public_path, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.dig('form', 'brand_logo_url')).to start_with('/rails/active_storage/blobs/')
  end

  it 'requires a valid Turnstile response when the public form enables it' do
    template.update!(settings: {
                       'captcha_provider' => 'turnstile',
                       'captcha_site_key' => 'turnstile-public-key'
                     })
    version
    verifier = instance_double(Forms::TurnstileVerificationService, valid?: true)
    allow(Forms::TurnstileVerificationService).to receive(:new).and_return(verifier)

    post "#{public_path}/respostas",
         params: {
           submission: {
             answers: { nome: 'Pedro Raevo', email: 'pedro@raevo.io', aceite: true },
             captcha_token: 'verified-token'
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    expect(Forms::TurnstileVerificationService).to have_received(:new).with(
      token: 'verified-token',
      remote_ip: kind_of(String)
    )
  end

  it 'rejects a public form submission without the configured Turnstile response' do
    template.update!(settings: {
                       'captcha_provider' => 'turnstile',
                       'captcha_site_key' => 'turnstile-public-key'
                     })
    version

    post "#{public_path}/respostas",
         params: { submission: { answers: { nome: 'Pedro Raevo', email: 'pedro@raevo.io', aceite: true } } },
         as: :json

    expect(response).to have_http_status(:unprocessable_entity)
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

  def phone_schema
    {
      'crm_mapping' => {
        'contact' => { 'name' => 'nome', 'phone_number' => 'telefone' }
      },
      'sections' => [
        {
          'key' => 'identificacao',
          'fields' => [
            { 'key' => 'nome', 'type' => 'text', 'label' => 'Nome', 'required' => true },
            { 'key' => 'telefone', 'type' => 'phone', 'label' => 'Telefone', 'required' => true }
          ]
        }
      ]
    }
  end
end
