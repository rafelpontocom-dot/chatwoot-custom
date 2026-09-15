require 'rails_helper'

RSpec.describe KanbanBoards::CreateFromTemplateService do
  let(:account) { create(:account) }

  def build_board(template_key)
    described_class.new(account: account, attributes: { name: 'Funil' }, template_key: template_key).perform!
  end

  it 'gives a clinic funnel the fields a clinic always needs' do
    board = build_board('clinic')

    expect(board.custom_field_definitions.pluck('key')).to include('procedimento', 'valor_orcado', 'data_procedimento')
    expect(board.compact_card_field_keys).to eq(%w[procedimento valor_orcado data_procedimento])
    expect(board.custom_field_definitions.first['layout']).to include('section' => 'details', 'position' => 1)
  end

  it 'creates every template field full width, so a new account starts readable' do
    %w[clinic b2b].each do |template_key|
      board = described_class.new(account: account, attributes: { name: template_key }, template_key: template_key).perform!
      widths = board.custom_field_definitions.map { |definition| definition['layout']['width'] }

      expect(widths).to all(eq('full')), template_key
    end
  end

  it 'leaves a blank funnel blank' do
    board = build_board('blank')

    expect(board.custom_field_definitions).to eq([])
    expect(board.kanban_stages).to be_empty
  end

  it 'still creates the stages of the template' do
    board = build_board('clinic')

    expect(board.kanban_stages.order(:position).pluck(:name).first).to eq('Novo lead')
  end
end
