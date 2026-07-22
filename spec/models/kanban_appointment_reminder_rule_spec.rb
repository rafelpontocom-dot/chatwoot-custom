require 'rails_helper'

RSpec.describe KanbanAppointmentReminderRule do
  it 'accepts a stage trigger and a datetime field' do
    board = create(:kanban_board)
    stage = create(:kanban_stage, account: board.account, kanban_board: board)

    rule = described_class.new(
      account: board.account,
      kanban_board: board,
      trigger_type: 'stage_entered',
      trigger_stage_id: stage.id,
      field_key: 'data_hora_consulta',
      offsets: [48, 24],
      channels: ['whatsapp'],
      message_templates: { '24' => 'Sua consulta será amanhã.' }
    )

    expect(rule).to be_valid
  end

  it 'requires a stage for a stage trigger' do
    rule = build(:kanban_appointment_reminder_rule, trigger_type: 'stage_entered', trigger_stage_id: nil)

    expect(rule).not_to be_valid
    expect(rule.errors[:trigger_stage_id]).to be_present
  end
end
