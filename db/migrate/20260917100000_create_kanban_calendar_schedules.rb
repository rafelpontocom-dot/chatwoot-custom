# Horário com nome, que várias agendas usam. Oito agendas no horário comercial
# eram a mesma semana configurada oito vezes — e corrigida oito vezes.
#
# A agenda continua a poder ter horário só dela (as regras que já tem): nenhuma
# muda de horário quando isto sobe. Usar um horário nomeado é uma escolha.
class CreateKanbanCalendarSchedules < ActiveRecord::Migration[7.1]
  def change # rubocop:disable Metrics/MethodLength
    create_table :kanban_calendar_schedules do |t|
      t.references :account, null: false, foreign_key: true, index: true
      # Preenchido = horário privado de um procedimento, fora da lista da conta.
      t.references :kanban_calendar_procedure, foreign_key: true, index: true
      t.string :name, null: false
      t.string :timezone, null: false
      t.boolean :default_schedule, null: false, default: false
      t.timestamps
    end
    add_index :kanban_calendar_schedules, 'account_id, lower((name)::text)',
              unique: true, where: 'kanban_calendar_procedure_id IS NULL',
              name: 'index_calendar_schedules_on_account_and_lower_name'
    add_index :kanban_calendar_schedules, :account_id,
              unique: true, where: 'default_schedule = true',
              name: 'index_calendar_schedules_on_account_default'

    add_reference :kanban_calendar_availability_rules, :kanban_calendar_schedule, foreign_key: true, index: true
    change_column_null :kanban_calendar_availability_rules, :kanban_calendar_resource_id, true
    add_column :kanban_calendar_availability_rules, :note, :string
    add_check_constraint :kanban_calendar_availability_rules,
                         '(kanban_calendar_schedule_id IS NULL) <> (kanban_calendar_resource_id IS NULL)',
                         name: 'calendar_rule_belongs_to_one_owner'

    add_reference :kanban_calendar_resources, :kanban_calendar_schedule, foreign_key: true, index: true
  end
end
