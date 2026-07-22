FactoryBot.define do
  factory :kanban_appointment_reminder_rule do
    account
    kanban_board { association(:kanban_board, account: account) }
    trigger_type { 'stage_entered' }
    trigger_stage { association(:kanban_stage, kanban_board: kanban_board, account: account) }
    field_key { 'data_hora_consulta' }
    offsets { [24] }
    channels { ['whatsapp'] }
    message_templates { { '24' => 'Lembrete de consulta.' } }
    active { true }
  end
end
