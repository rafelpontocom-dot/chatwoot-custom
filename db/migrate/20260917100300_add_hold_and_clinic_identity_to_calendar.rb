# A página pública em três passos: a vaga fica reservada enquanto o paciente
# preenche (e, com cobrança, até o pagamento confirmar), o horário é mostrado
# no fuso de quem marca, e a página diz que clínica é.
class AddHoldAndClinicIdentityToCalendar < ActiveRecord::Migration[7.1]
  def change
    change_table :kanban_calendar_appointments, bulk: true do |t|
      t.datetime :hold_expires_at
      t.string :booking_timezone
      t.string :hold_token
    end
    add_index :kanban_calendar_appointments, :hold_expires_at, where: 'hold_expires_at IS NOT NULL',
                                                               name: 'index_calendar_appointments_on_hold_expires_at'
    add_index :kanban_calendar_appointments, :hold_token, unique: true, where: 'hold_token IS NOT NULL',
                                                          name: 'index_calendar_appointments_on_hold_token'

    change_table :kanban_calendar_booking_pages, bulk: true do |t|
      t.string :clinic_name
      t.string :clinic_address
      t.string :clinic_whatsapp
    end
  end
end
