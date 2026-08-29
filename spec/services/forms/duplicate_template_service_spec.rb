require 'rails_helper'

RSpec.describe Forms::DuplicateTemplateService do
  let(:account) { create(:account) }
  let(:card) { create(:kanban_card, account: account) }
  let(:source) do
    FormTemplate.create!(
      account: account,
      name: 'Captação de consulta',
      slug: 'captacao-consulta',
      category: 'lead_capture',
      access_classification: 'commercial',
      public_enabled: true,
      settings: { 'locale' => 'pt_BR', 'theme' => 'warm' }
    )
  end

  before do
    source.publish!(
      schema: {
        'crm_destination' => {
          'kanban_board_id' => card.kanban_board_id,
          'kanban_stage_id' => card.kanban_stage_id,
          'inbox_id' => card.inbox_id,
          'opportunity_policy' => 'reuse_open'
        },
        'crm_mapping' => {
          'contact' => { 'name' => 'nome', 'phone_number' => 'telefone' }
        },
        'sections' => [
          {
            'key' => 'dados',
            'fields' => [
              { 'key' => 'nome', 'label' => 'Nome', 'type' => 'text' },
              { 'key' => 'telefone', 'label' => 'Telefone', 'type' => 'phone' }
            ]
          }
        ]
      }
    )
  end

  it 'creates an independent private copy with the active schema' do
    copy = described_class.new(
      source: source,
      name: 'Captação de consulta - cópia',
      slug: 'captacao-consulta-copia'
    ).perform

    expect(copy).to have_attributes(
      account: account,
      name: 'Captação de consulta - cópia',
      slug: 'captacao-consulta-copia',
      public_enabled: false,
      category: 'lead_capture'
    )
    expect(copy.active_version).to be_present
    expect(copy.active_version.schema).to eq(source.active_version.schema)
    expect(copy.active_version).not_to eq(source.active_version)
  end
end
