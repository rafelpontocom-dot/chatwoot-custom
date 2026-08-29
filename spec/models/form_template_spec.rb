require 'rails_helper'

RSpec.describe FormTemplate do
  let(:account) { create(:account) }

  it 'publishes an immutable version and makes it the active version' do
    template = described_class.create!(
      account: account,
      name: 'Pré-consulta',
      slug: 'pre-consulta',
      category: 'pre_consultation',
      access_classification: 'commercial'
    )

    version = template.publish!(schema: schema)

    expect(template.reload.active_version).to eq(version)
    expect(version).to have_attributes(
      account: account,
      form_template: template,
      version_number: 1,
      schema: schema
    )
    expect { version.update!(schema: updated_schema) }.to raise_error(ActiveRecord::RecordNotSaved)
  end

  it 'rejects a published schema without sections' do
    template = described_class.create!(
      account: account,
      name: 'Captação',
      slug: 'captacao',
      category: 'lead_capture',
      access_classification: 'commercial'
    )

    expect { template.publish!(schema: { 'title' => 'Captação' }) }
      .to raise_error(ActiveRecord::RecordInvalid, /include at least one section/)
  end

  it 'does not publish a public commercial form without contact mapping' do
    template = described_class.create!(
      account: account,
      name: 'Captação',
      slug: 'captacao-publica',
      category: 'lead_capture',
      access_classification: 'commercial',
      public_enabled: true
    )

    expect { template.publish!(schema: schema) }
      .to raise_error(ActiveRecord::RecordInvalid, /name and email or phone/)
  end

  it 'does not enable public access for a published form without contact mapping' do
    template = described_class.create!(
      account: account,
      name: 'Captação',
      slug: 'captacao-privada',
      category: 'lead_capture',
      access_classification: 'commercial'
    )
    template.publish!(schema: schema)

    expect { template.update!(public_enabled: true) }
      .to raise_error(ActiveRecord::RecordInvalid, /name and email or phone/)
  end

  it 'requires an explicit clinical consent before publishing an anamnese' do
    template = described_class.create!(
      account: account,
      name: 'Anamnese inicial',
      slug: 'anamnese-inicial',
      category: 'clinical',
      access_classification: 'sensitive_health'
    )

    expect { template.publish!(schema: schema) }
      .to raise_error(ActiveRecord::RecordInvalid, /clinical consent/)
  end

  it 'does not allow an anamnese to be made public' do
    template = described_class.new(
      account: account,
      name: 'Anamnese inicial',
      slug: 'anamnese-inicial',
      category: 'clinical',
      access_classification: 'sensitive_health',
      public_enabled: true
    )

    expect(template).not_to be_valid
    expect(template.errors[:public_enabled]).to include('cannot be enabled for sensitive health forms')
  end

  it 'rejects clinical access references outside the account' do
    other_user = create(:user, account: create(:account), role: :agent)
    template = described_class.new(
      account: account,
      name: 'Anamnese inicial',
      slug: 'anamnese-com-acesso-externo',
      category: 'clinical',
      access_classification: 'sensitive_health',
      settings: { 'clinical_access' => { 'user_ids' => [other_user.id] } }
    )

    expect(template).not_to be_valid
    expect(template.errors[:settings]).to include('contains a user outside this account')
  end

  it 'rejects an invalid clinical retention period' do
    template = described_class.new(
      account: account,
      name: 'Anamnese inicial',
      slug: 'anamnese-retencao-invalida',
      category: 'clinical',
      access_classification: 'sensitive_health',
      settings: { 'clinical_retention_days' => 0 }
    )

    expect(template).not_to be_valid
    expect(template.errors[:settings]).to include('clinical retention must be at least one day')
  end

  it 'exposes the configured clinical retention period' do
    template = described_class.create!(
      account: account,
      name: 'Anamnese inicial',
      slug: 'anamnese-retencao',
      category: 'clinical',
      access_classification: 'sensitive_health',
      settings: { 'clinical_retention_days' => 365 }
    )

    expect(template.clinical_retention_days).to eq(365)
  end

  it 'requires a public key when Turnstile is enabled for a public form' do
    template = described_class.new(
      account: account,
      name: 'Captação protegida',
      slug: 'captacao-protegida',
      category: 'lead_capture',
      access_classification: 'commercial',
      settings: { 'captcha_provider' => 'turnstile' }
    )

    expect(template).not_to be_valid
    expect(template.errors[:settings]).to include('captcha site key is required')
  end

  it 'rejects CRM destinations and mappings in an anamnese schema' do
    with_modified_env 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' => 'forms-test-encryption-key' do
      template = described_class.create!(
        account: account,
        name: 'Anamnese inicial',
        slug: 'anamnese-inicial',
        category: 'clinical',
        access_classification: 'sensitive_health'
      )
      sensitive_schema = schema.deep_merge(
        'sections' => [
          {
            'key' => 'saude',
            'fields' => [
              { 'key' => 'alergias', 'type' => 'textarea', 'label' => 'Alergias', 'required' => true },
              { 'key' => 'consentimento', 'type' => 'consent', 'label' => 'Autorizo', 'required' => true }
            ]
          }
        ],
        'crm_destination' => {
          'kanban_board_id' => 1,
          'kanban_stage_id' => 1,
          'inbox_id' => 1,
          'opportunity_policy' => 'create_new'
        },
        'crm_mapping' => { 'contact' => { 'name' => 'alergias' } }
      )

      expect { template.publish!(schema: sensitive_schema) }
        .to raise_error(ActiveRecord::RecordInvalid, /cannot include CRM mapping or destination/)
    end
  end

  it 'removes its published versions when the template is removed' do
    template = described_class.create!(
      account: account,
      name: 'Captação',
      slug: 'captacao',
      category: 'lead_capture',
      access_classification: 'commercial'
    )
    version = template.publish!(schema: schema)

    template.destroy!

    expect(described_class).not_to exist(template.id)
    expect(FormTemplateVersion).not_to exist(version.id)
  end

  it 'generates a public token when an existing template enables public access' do
    template = described_class.create!(
      account: account,
      name: 'Captação',
      slug: 'captacao',
      category: 'lead_capture',
      access_classification: 'commercial'
    )
    template.update_column(:public_token, nil) # rubocop:disable Rails/SkipsModelValidations

    template.update!(public_enabled: true)

    expect(template.public_token).to be_present
  end

  private

  def schema
    {
      'sections' => [
        {
          'key' => 'identificacao',
          'title' => 'Identificação',
          'fields' => [
            { 'key' => 'nome', 'type' => 'text', 'label' => 'Nome completo' }
          ]
        }
      ]
    }
  end

  def updated_schema
    schema.deep_merge('sections' => [{ 'key' => 'atualizado', 'fields' => [] }])
  end
end
