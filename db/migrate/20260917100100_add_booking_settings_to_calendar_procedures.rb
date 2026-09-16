# O que hoje é regra da conta inteira passa a poder ser do procedimento: a
# avaliação de 50 minutos e o retorno de 15 deixam de obedecer à mesma regra.
#
# Nulo em limites quer dizer «o padrão da conta», que continua na página de
# agendamento — o mesmo contrato que o espaçamento já tem na agenda.
class AddBookingSettingsToCalendarProcedures < ActiveRecord::Migration[7.1]
  def change # rubocop:disable Metrics/MethodLength
    change_table :kanban_calendar_procedures, bulk: true do |t|
      t.string :availability_mode, null: false, default: 'resources'
      t.string :assignment_strategy, null: false, default: 'patient_choice'
      t.integer :minimum_notice_minutes
      t.integer :maximum_notice_days
      t.integer :slot_interval_minutes
      t.integer :daily_limit
      t.boolean :payment_enabled, null: false, default: false
      t.integer :price_cents
      t.string :payment_mode, null: false, default: 'full'
      t.integer :deposit_cents
      t.jsonb :payment_methods, null: false, default: %w[pix card on_site]
      t.integer :hold_minutes, null: false, default: 10
      t.boolean :reschedule_allowed, null: false, default: true
      t.boolean :cancel_allowed, null: false, default: true
      t.integer :change_deadline_hours, null: false, default: 12
      t.boolean :cancel_reason_required, null: false, default: true
      t.string :on_cancel_stage_action, null: false, default: 'back_to_scheduling'
    end
    add_reference :kanban_calendar_procedures, :kanban_calendar_schedule, foreign_key: true, index: true
  end
end
