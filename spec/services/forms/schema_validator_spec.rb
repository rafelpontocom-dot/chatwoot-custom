require 'rails_helper'

RSpec.describe Forms::SchemaValidator do
  it 'accepts a structured schema with reusable field types' do
    validator = described_class.new(
      'sections' => [
        {
          'key' => 'identificacao',
          'fields' => [
            { 'key' => 'nome', 'type' => 'text', 'label' => 'Nome completo' },
            {
              'key' => 'canal',
              'type' => 'select',
              'label' => 'Canal preferido',
              'options' => %w[WhatsApp Telefone]
            }
          ]
        }
      ]
    )

    expect(validator).to be_valid
  end

  it 'accepts a visual acceptance signature' do
    validator = described_class.new(
      'sections' => [
        {
          'key' => 'aceite',
          'fields' => [
            {
              'key' => 'assinatura_paciente',
              'type' => 'signature',
              'label' => 'Digite seu nome para confirmar o aceite'
            }
          ]
        }
      ]
    )

    expect(validator).to be_valid
  end

  it 'rejects repeated field keys across sections' do
    validator = described_class.new(
      'sections' => [
        { 'key' => 'identificacao', 'fields' => [{ 'key' => 'nome', 'type' => 'text', 'label' => 'Nome' }] },
        { 'key' => 'consulta', 'fields' => [{ 'key' => 'nome', 'type' => 'text', 'label' => 'Como prefere ser chamado?' }] }
      ]
    )

    expect(validator).not_to be_valid
    expect(validator.errors).to include('field keys must be unique')
  end

  it 'rejects selection fields without options' do
    validator = described_class.new(
      'sections' => [
        { 'key' => 'consulta', 'fields' => [{ 'key' => 'canal', 'type' => 'select', 'label' => 'Canal' }] }
      ]
    )

    expect(validator).not_to be_valid
    expect(validator.errors).to include('selection fields must include options')
  end

  it 'rejects a conditional field without a supported condition' do
    validator = described_class.new(
      'sections' => [
        {
          'key' => 'consulta',
          'fields' => [
            { 'key' => 'deseja_consulta', 'type' => 'select', 'label' => 'Deseja consultar?', 'options' => %w[sim nao] },
            {
              'key' => 'melhor_horario',
              'type' => 'text',
              'label' => 'Melhor horário',
              'visible_when' => { 'field' => 'deseja_consulta', 'operator' => 'contains' }
            }
          ]
        }
      ]
    )

    expect(validator).not_to be_valid
    expect(validator.errors).to include('conditional fields must use a supported condition')
  end

  it 'rejects a conditional field that references an unknown question' do
    validator = described_class.new(
      'sections' => [
        {
          'key' => 'consulta',
          'fields' => [
            {
              'key' => 'melhor_horario',
              'type' => 'text',
              'label' => 'Melhor horário',
              'visible_when' => { 'field' => 'deseja_consulta', 'operator' => 'equals', 'value' => 'sim' }
            }
          ]
        }
      ]
    )

    expect(validator).not_to be_valid
    expect(validator.errors).to include('conditional fields must reference an existing field')
  end

  it 'rejects an incomplete CRM destination' do
    validator = described_class.new(
      'crm_destination' => {
        'kanban_board_id' => 4,
        'kanban_stage_id' => 7,
        'opportunity_policy' => 'reuse_open'
      },
      'sections' => [
        { 'key' => 'identificacao', 'fields' => [{ 'key' => 'nome', 'type' => 'text', 'label' => 'Nome' }] }
      ]
    )

    expect(validator).not_to be_valid
    expect(validator.errors).to include('CRM destination must define a valid board, stage, inbox, and opportunity policy')
  end

  it 'rejects opportunity field mapping without a CRM destination' do
    validator = described_class.new(
      'crm_mapping' => {
        'kanban_card' => {
          'custom_field_values' => { 'origem_lead' => 'origem' }
        }
      },
      'sections' => [
        { 'key' => 'identificacao', 'fields' => [{ 'key' => 'origem', 'type' => 'text', 'label' => 'Origem' }] }
      ]
    )

    expect(validator).not_to be_valid
    expect(validator.errors).to include('opportunity mapping requires a CRM destination')
  end

  it 'requires contact mapping before a commercial form is published publicly' do
    validator = described_class.new(
      {
        'sections' => [
          {
            'key' => 'identificacao',
            'fields' => [
              { 'key' => 'nome', 'type' => 'text', 'label' => 'Nome' },
              { 'key' => 'telefone', 'type' => 'phone', 'label' => 'Telefone' }
            ]
          }
        ],
        'crm_mapping' => { 'contact' => { 'name' => 'nome' } }
      },
      require_public_contact_mapping: true
    )

    expect(validator).not_to be_valid
    expect(validator.errors).to include('public forms require contact mapping for name and email or phone')
  end

  it 'accepts contact name and phone mappings for a public form' do
    validator = described_class.new(
      {
        'sections' => [
          {
            'key' => 'identificacao',
            'fields' => [
              { 'key' => 'nome', 'type' => 'text', 'label' => 'Nome' },
              { 'key' => 'telefone', 'type' => 'phone', 'label' => 'Telefone' }
            ]
          }
        ],
        'crm_mapping' => {
          'contact' => { 'name' => 'nome', 'phone_number' => 'telefone' }
        }
      },
      require_public_contact_mapping: true
    )

    expect(validator).to be_valid
  end

  it 'rejects attachment questions when the form is not allowed to collect clinical files' do
    validator = described_class.new(
      'sections' => [
        {
          'key' => 'documentos',
          'fields' => [
            { 'key' => 'exame', 'type' => 'attachment', 'label' => 'Exame recente' }
          ]
        }
      ]
    )

    expect(validator).not_to be_valid
    expect(validator.errors).to include('attachment fields require a private clinical form')
  end
end
