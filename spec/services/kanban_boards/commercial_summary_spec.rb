require 'rails_helper'

RSpec.describe KanbanBoards::CommercialSummary do
  let(:account) { create(:account) }
  let(:board) { create(:kanban_board, account: account) }
  let(:stage) { create(:kanban_stage, account: account, kanban_board: board) }
  let(:card_attributes) do
    { account: account, kanban_board: board, kanban_stage: stage }
  end

  it 'sums only what is still open into the pipeline value' do
    create(:kanban_card, **card_attributes, amount_cents: 480_000)
    create(:kanban_card, **card_attributes, amount_cents: 120_000, won_at: Time.zone.now)
    # `lost_at` sem `lost_reason` não passa a validação do cartão, por isso a
    # razão vem sempre com a data — aqui e na taxa de fecho, mais abaixo.
    create(:kanban_card, **card_attributes, amount_cents: 90_000, lost_at: Time.zone.now, lost_reason: 'Preço')
    create(:kanban_card, **card_attributes, amount_cents: 70_000, archived_at: Time.zone.now)

    expect(described_class.new(board: board).call[:pipeline_value][:current]).to eq(480_000)
  end

  it 'reads the close rate as won over closed, and nil when nothing closed' do
    travel_to Time.zone.parse('2026-09-18 10:00') do
      create(:kanban_card, **card_attributes, won_at: Time.zone.parse('2026-09-04'))
      create(:kanban_card, **card_attributes, won_at: Time.zone.parse('2026-09-06'))
      create(:kanban_card, **card_attributes, lost_at: Time.zone.parse('2026-09-08'), lost_reason: 'Sem resposta')

      resumo = described_class.new(board: board).call[:close_rate]

      expect(resumo[:current]).to eq(66.7)
      expect(resumo[:closed]).to eq(3)
      # Agosto não teve nada fechado: nil, e não zero. Zero por cento diria que se
      # perdeu tudo, quando não houve nada para ganhar nem para perder.
      expect(resumo[:previous]).to be_nil
    end
  end

  it 'averages the days between creating and winning' do
    travel_to Time.zone.parse('2026-09-18 10:00') do
      create(:kanban_card, **card_attributes, created_at: Time.zone.parse('2026-09-01'),
                                              won_at: Time.zone.parse('2026-09-11'))
      create(:kanban_card, **card_attributes, created_at: Time.zone.parse('2026-09-01'),
                                              won_at: Time.zone.parse('2026-09-21'))

      expect(described_class.new(board: board).call[:cycle_days][:current]).to eq(15)
    end
  end

  it 'reports the cycle as nil when the month has no win to measure' do
    expect(described_class.new(board: board).call[:cycle_days][:current]).to be_nil
  end

  it 'counts and totals what was won in each month' do
    travel_to Time.zone.parse('2026-09-18 10:00') do
      create(:kanban_card, **card_attributes, amount_cents: 300_000,
                                              won_at: Time.zone.parse('2026-09-05'))
      create(:kanban_card, **card_attributes, amount_cents: 82_000,
                                              won_at: Time.zone.parse('2026-09-09'))
      create(:kanban_card, **card_attributes, amount_cents: 210_000,
                                              won_at: Time.zone.parse('2026-08-14'))

      resumo = described_class.new(board: board).call[:won]

      expect(resumo[:current]).to eq(count: 2, amount_cents: 382_000)
      expect(resumo[:previous]).to eq(count: 1, amount_cents: 210_000)
    end
  end
end
