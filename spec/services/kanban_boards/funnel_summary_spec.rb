require 'rails_helper'

RSpec.describe KanbanBoards::FunnelSummary do
  let(:account) { create(:account) }
  let(:board) { create(:kanban_board, account: account) }
  let(:primeira) { create(:kanban_stage, account: account, kanban_board: board, position: 1, category: 'open') }
  let(:segunda) { create(:kanban_stage, account: account, kanban_board: board, position: 2, category: 'open') }
  let(:card_attributes) { { account: account, kanban_board: board } }

  def linha(stage)
    described_class.new(board: board).call[:stages].find { |row| row[:id] == stage.id }
  end

  it 'counts the stage where a card was created as an entry' do
    create(:kanban_card, **card_attributes, kanban_stage: primeira)

    expect(linha(primeira)).to include(entered: 1, advanced: 0, conversion: 0.0)
  end

  it 'counts an advance for the stage the card left, not for the one it reached' do
    card = create(:kanban_card, **card_attributes, kanban_stage: primeira)
    card.update!(kanban_stage: segunda)

    expect(linha(primeira)).to include(entered: 1, advanced: 1, conversion: 100.0)
    expect(linha(segunda)).to include(entered: 1, advanced: 0)
  end

  it 'does not read a move backwards as an advance' do
    card = create(:kanban_card, **card_attributes, kanban_stage: segunda)
    card.update!(kanban_stage: primeira)

    expect(linha(segunda)[:advanced]).to eq(0)
    expect(linha(primeira)[:entered]).to eq(1)
  end

  # Sem entradas a conversão é nil e não zero: zero por cento diria que ninguém
  # avançou, quando não houve ninguém para avançar.
  it 'reports the conversion as nil for a stage nothing entered' do
    create(:kanban_card, **card_attributes, kanban_stage: primeira)

    expect(linha(segunda)).to include(entered: 0, conversion: nil)
  end

  # As quatro contagens respondem a perguntas diferentes, e a tela mostra-as lado
  # a lado em vez de as somar: uma oportunidade que entrou e ainda está aberta não
  # é uma perda.
  it 'keeps what was lost and what is still open apart from the flow counts' do
    create(:kanban_card, **card_attributes, kanban_stage: primeira, lost_at: Time.zone.now, lost_reason: 'Preço')
    create(:kanban_card, **card_attributes, kanban_stage: primeira)

    expect(linha(primeira)).to include(entered: 2, lost: 1, open: 1)
  end
end
