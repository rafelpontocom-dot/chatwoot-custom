require 'rails_helper'

RSpec.describe Forms::PublicPayloadBuilder do
  let(:account) { create(:account) }
  let(:template) do
    FormTemplate.create!(
      account: account,
      name: 'Pré-consulta',
      slug: 'pre-consulta-guiada',
      category: 'pre_consultation',
      access_classification: 'commercial',
      settings: settings
    )
  end
  let(:settings) { { 'presentation' => 'guided' } }
  let(:schema) do
    {
      'crm_destination' => {
        'kanban_board_id' => 1,
        'kanban_stage_id' => 1,
        'inbox_id' => 1,
        'opportunity_policy' => 'reuse_open'
      },
      'sections' => [{ 'key' => 'inicio', 'fields' => [{ 'key' => 'nome', 'label' => 'Nome', 'type' => 'text' }] }]
    }
  end

  it 'exposes the configured guided presentation to the public renderer' do
    template.publish!(schema: schema)

    payload = described_class.new(form_template: template).call

    expect(payload.dig(:form, :presentation)).to eq('guided')
  end

  it 'keeps legacy commercial forms guided when presentation is absent' do
    template.update!(settings: {})
    template.publish!(schema: schema)

    payload = described_class.new(form_template: template).call

    expect(payload.dig(:form, :presentation)).to eq('guided')
  end

  it 'keeps sensitive-health forms sectioned when presentation is absent' do
    with_modified_env 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' => 'forms-test-encryption-key' do
      template.update!(
        category: 'clinical',
        access_classification: 'sensitive_health',
        settings: {}
      )
      template.publish!(
        schema: {
          'sections' => [
            {
              'key' => 'saude',
              'fields' => [
                {
                  'key' => 'consentimento_clinico',
                  'label' => 'Autorizo',
                  'type' => 'consent',
                  'required' => true
                }
              ]
            }
          ]
        }
      )

      payload = described_class.new(form_template: template).call

      expect(payload.dig(:form, :presentation)).to eq('sectioned')
    end
  end
end
