require 'rails_helper'
require Rails.root.join('db/migrate/20260907120000_repoint_appointment_reminders_to_calendar_field')

RSpec.describe RepointAppointmentRemindersToCalendarField do
  let(:account) { create(:account) }
  let(:migration) { described_class.new }

  before { migration.verbose = false }

  # O lembrete lia uma data digitada a mao que a remarcacao nunca tocava.
  it 'points a rule at the field the calendar keeps in sync' do
    board = create(:kanban_board, account: account, calendar_legacy_next_appointment_field_key: 'data_da_consulta')
    rule = create(:kanban_appointment_reminder_rule, account: account, kanban_board: board, field_key: 'system_starts_at')

    migration.up

    expect(rule.reload.field_key).to eq('data_da_consulta')
  end

  # Desativar por conta propria calaria um lembrete que talvez ainda saia.
  it 'leaves a rule alone when its board has no calendar field' do
    board = create(:kanban_board, account: account, calendar_legacy_next_appointment_field_key: nil)
    rule = create(:kanban_appointment_reminder_rule, account: account, kanban_board: board, field_key: 'system_starts_at')

    migration.up

    expect(rule.reload.field_key).to eq('system_starts_at')
  end

  it 'does not touch a rule that already reads a custom field' do
    board = create(:kanban_board, account: account, calendar_legacy_next_appointment_field_key: 'data_da_consulta')
    rule = create(:kanban_appointment_reminder_rule, account: account, kanban_board: board, field_key: 'outra_data')

    migration.up

    expect(rule.reload.field_key).to eq('outra_data')
  end
end
