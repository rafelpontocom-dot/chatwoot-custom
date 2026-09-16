# Vaga segura enquanto o paciente preenche os dados na página pública. Ainda
# não há contato, por isso não pode ser uma consulta; ocupa o horário das
# agendas escolhidas até expirar ou virar consulta.
class CreateKanbanCalendarSlotHolds < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_calendar_slot_holds do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :kanban_calendar_procedure, null: false, foreign_key: true, index: true
      t.integer :resource_ids, array: true, null: false, default: []
      t.datetime :starts_at, null: false
      t.datetime :reserved_from, null: false
      t.datetime :reserved_until, null: false
      t.string :timezone, null: false
      t.string :token, null: false
      t.datetime :expires_at, null: false
      # A remarcação de uma consulta já existente usa a mesma reserva.
      t.references :kanban_calendar_appointment, foreign_key: true, index: true
      t.timestamps
    end
    add_index :kanban_calendar_slot_holds, :token, unique: true
    add_index :kanban_calendar_slot_holds, :expires_at
    add_index :kanban_calendar_slot_holds, :resource_ids, using: :gin
  end
end
