require 'rails_helper'

RSpec.describe Forms::CreatePublicOpportunityService do
  let(:account) { create(:account) }
  let(:board) { create(:kanban_board, account: account) }
  let(:stage) { create(:kanban_stage, account: account, kanban_board: board) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Pedro Raevo') }
  let(:template) do
    FormTemplate.create!(
      account: account,
      name: 'Captação clínica',
      slug: 'captacao-clinica',
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
      answers: { 'nome' => contact.name },
      submitted_at: Time.current
    )
  end

  it 'creates an opportunity in the configured destination and links the submission' do
    card = described_class.new(submission: submission).perform

    expect(card).to have_attributes(
      account: account,
      kanban_board: board,
      kanban_stage: stage,
      inbox: inbox,
      contact: contact,
      origin: 'manual'
    )
    expect(submission.reload.kanban_card).to eq(card)
  end

  it 'reuses an open opportunity when the destination policy requests it' do
    existing_card = create(
      :kanban_card,
      account: account,
      kanban_board: board,
      kanban_stage: stage,
      inbox: inbox,
      contact: contact
    )

    expect(described_class.new(submission: submission).perform).to eq(existing_card)
    expect(submission.reload.kanban_card).to eq(existing_card)
  end

  it 'maps declared answers to custom fields of the linked opportunity' do
    board.update!(
      custom_field_definitions: [
        {
          'key' => 'origem_lead',
          'label' => 'Origem do lead',
          'field_type' => 'select',
          'options' => %w[Formulario Indicacao]
        }
      ]
    )
    version.update_column( # rubocop:disable Rails/SkipsModelValidations
      :schema,
      schema.deep_merge(
        'crm_mapping' => {
          'kanban_card' => {
            'custom_field_values' => { 'origem_lead' => 'origem' }
          }
        }
      )
    )
    submission.update!(answers: { 'nome' => contact.name, 'origem' => 'Formulario' })

    card = described_class.new(submission: submission).perform

    expect(card.reload.custom_field_values).to eq('origem_lead' => 'Formulario')
  end

  it 'keeps the submission when its configured destination is invalid' do
    version.update_column(:schema, schema.deep_merge('crm_destination' => { 'kanban_stage_id' => 0 })) # rubocop:disable Rails/SkipsModelValidations

    expect(described_class.new(submission: submission).perform).to be_nil
    expect(submission.reload.kanban_card).to be_nil
    expect(submission.metadata.dig('crm_destination', 'status')).to eq('failed')
  end

  private

  def schema
    {
      'crm_destination' => {
        'kanban_board_id' => board.id,
        'kanban_stage_id' => stage.id,
        'inbox_id' => inbox.id,
        'opportunity_policy' => 'reuse_open'
      },
      'sections' => [
        {
          'key' => 'principal',
          'fields' => [
            { 'key' => 'nome', 'type' => 'text', 'label' => 'Nome', 'required' => true }
          ]
        }
      ]
    }
  end
end
