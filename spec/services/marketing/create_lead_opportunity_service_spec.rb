require 'rails_helper'

RSpec.describe Marketing::CreateLeadOpportunityService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:board) do
    create(:kanban_board, account: account, custom_field_definitions: [
             { 'key' => 'procedimento', 'label' => 'Procedimento', 'field_type' => 'text' },
             { 'key' => 'convenio', 'label' => 'Convênio', 'field_type' => 'text' }
           ])
  end
  let(:stage) { create(:kanban_stage, account: account, kanban_board: board) }
  let(:contact) { create(:contact, account: account, name: 'Maria') }
  let(:destination) do
    { 'kanban_board_id' => board.id, 'kanban_stage_id' => stage.id, 'inbox_id' => inbox.id }
  end

  before { create(:kanban_board_inbox, account: account, kanban_board: board, inbox: inbox) }

  def create_card(answers)
    described_class.new(
      account: account, contact: contact, destination: destination,
      subject: 'Lead do Meta', answers: answers
    ).perform
  end

  it 'writes an answer the board defines as a custom field' do
    card = create_card('procedimento' => 'Preenchimento labial')

    expect(card.custom_field_values).to eq('procedimento' => 'Preenchimento labial')
  end

  it 'ignores an answer the board does not define' do
    card = create_card('procedimento' => 'Botox', 'pergunta_solta' => 'valor qualquer')

    expect(card.custom_field_values).to eq('procedimento' => 'Botox')
  end

  it 'ignores contact fields that are not board fields' do
    card = create_card('name' => 'Maria', 'email' => 'maria@clinica.pt', 'convenio' => 'Unimed')

    expect(card.custom_field_values).to eq('convenio' => 'Unimed')
  end

  it 'drops an answer the lead left blank instead of storing an empty field' do
    card = create_card('procedimento' => '  ', 'convenio' => 'Amil')

    expect(card.custom_field_values).to eq('convenio' => 'Amil')
  end

  it 'creates the card without custom values when nothing was mapped' do
    card = create_card({})

    expect(card.custom_field_values).to eq({})
  end
end
