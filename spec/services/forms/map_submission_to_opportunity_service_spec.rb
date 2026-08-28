require 'rails_helper'

RSpec.describe Forms::MapSubmissionToOpportunityService do
  let(:account) { create(:account) }
  let(:board) do
    create(
      :kanban_board,
      account: account,
      custom_field_definitions: [
        {
          'key' => 'origem_lead',
          'label' => 'Origem do lead',
          'field_type' => 'select',
          'options' => %w[Formulario Indicacao]
        }
      ]
    )
  end
  let(:stage) { create(:kanban_stage, account: account, kanban_board: board) }
  let(:contact) { create(:contact, account: account, name: 'Pedro Raevo') }
  let(:card) do
    create(
      :kanban_card,
      account: account,
      kanban_board: board,
      kanban_stage: stage,
      contact: contact
    )
  end
  let(:template) do
    FormTemplate.create!(
      account: account,
      name: 'Captação',
      slug: 'captacao',
      category: 'lead_capture',
      access_classification: 'commercial'
    )
  end
  let(:version) { template.publish!(schema: schema) }
  let(:submission) do
    FormSubmission.create!(
      account: account,
      form_template_version: version,
      contact: contact,
      answers: { 'origem' => 'Formulario' },
      submitted_at: Time.current
    )
  end
  let(:crm_destination) do
    {
      'kanban_board_id' => board.id,
      'kanban_stage_id' => stage.id,
      'inbox_id' => card.inbox_id,
      'opportunity_policy' => 'reuse_open'
    }
  end
  let(:opportunity_mapping) do
    { 'custom_field_values' => { 'origem_lead' => 'origem' } }
  end
  let(:form_fields) do
    [
      {
        'key' => 'origem',
        'type' => 'select',
        'label' => 'Origem',
        'options' => %w[Formulario Indicacao]
      }
    ]
  end
  let(:schema) do
    {
      'crm_destination' => crm_destination,
      'crm_mapping' => { 'kanban_card' => opportunity_mapping },
      'sections' => [{ 'key' => 'identificacao', 'fields' => form_fields }]
    }
  end

  it 'maps a declared answer through the board field normalizer' do
    result = described_class.new(submission: submission, kanban_card: card).perform

    expect(result).to be_mapped
    expect(card.reload.custom_field_values).to eq('origem_lead' => 'Formulario')
  end

  it 'does not alter the opportunity when the mapped answer is invalid for the board field' do
    submission.update!(answers: { 'origem' => 'Canal inválido' })

    result = described_class.new(submission: submission, kanban_card: card).perform

    expect(result).to be_rejected
    expect(card.reload.custom_field_values).to eq({})
  end
end
