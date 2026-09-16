# Espaçamento entre horários oferecidos, por agenda. Nulo significa «o padrão da
# conta», que é o da página de agendamento — antes disto o cálculo ignorava as
# duas coisas e usava 15 minutos escritos no código.
class AddSlotIntervalToCalendarResources < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_calendar_resources, :slot_interval_minutes, :integer
  end
end
