require 'rails_helper'

RSpec.describe KanbanAppointmentReminders::ScheduleService do
  it 'schedules one delivery for each configured offset after a stage entry' do
    board = create(:kanban_board, custom_field_definitions: [{ key: 'data_hora_consulta', label: 'Data da consulta', field_type: 'datetime' }])
    stage = create(:kanban_stage, account: board.account, kanban_board: board)
    card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage,
                                custom_field_values: { 'data_hora_consulta' => 2.days.from_now.iso8601 })
    rule = create(:kanban_appointment_reminder_rule, account: board.account, kanban_board: board,
                                                     trigger_stage_id: stage.id, offsets: [48, 24])

    expect do
      described_class.new(card: card, rule: rule, appointment_version: 'v1').call
    end.to change(KanbanAppointmentReminderDelivery, :count).by(2)

    expect(rule.deliveries.pluck(:offset_hours)).to contain_exactly(48, 24)
  end

  it 'does not schedule a delivery when the appointment field is missing' do
    board = create(:kanban_board, custom_field_definitions: [{ key: 'data_hora_consulta', label: 'Data da consulta', field_type: 'datetime' }])
    rule = create(:kanban_appointment_reminder_rule, account: board.account, kanban_board: board)
    card = create(:kanban_card, account: board.account, kanban_board: board, custom_field_values: {})

    expect do
      described_class.new(card: card, rule: rule, appointment_version: 'v1').call
    end.not_to change(KanbanAppointmentReminderDelivery, :count)
  end
end
