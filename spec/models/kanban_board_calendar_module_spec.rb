require 'rails_helper'

RSpec.describe KanbanBoard do
  it 'keeps only stages and active procedures belonging to its account' do
    account = create(:account)
    board = create(:kanban_board, account: account)
    stage = create(:kanban_stage, account: account, kanban_board: board)
    procedure = KanbanCalendarProcedure.create!(
      account: account,
      name: 'Consulta inicial',
      duration_minutes: 50,
      recurrence_allowed: false
    )
    other_procedure = KanbanCalendarProcedure.create!(
      account: create(:account),
      name: 'Outro procedimento',
      duration_minutes: 50,
      recurrence_allowed: false
    )

    board.update!(
      calendar_enabled: true,
      calendar_booking_stage_ids: [stage.id, 999_999],
      calendar_procedure_ids: [procedure.id, other_procedure.id]
    )

    expect(board).to be_calendar_module_enabled
    expect(board.calendar_booking_stage_ids).to eq([stage.id])
    expect(board.configured_calendar_procedure_ids).to eq([procedure.id])
  end
end
