# O bloqueio de horário deixa de ser «do Google»: o Feegow entra como segundo
# provedor na mesma estrutura.
#
# Trocar a chave única e largar a coluna da conexão é seguro porque o bloqueio é
# cache — cada importação reconstrói a janela inteira. No pior caso perde-se um
# ciclo de cinco minutos.
class AddProviderToCalendarBusyBlocks < ActiveRecord::Migration[7.1]
  def up
    add_column :kanban_calendar_external_busy_blocks, :provider, :string, null: false, default: 'google_calendar'
    remove_index :kanban_calendar_external_busy_blocks, name: 'idx_calendar_busy_blocks_on_connection_event'
    add_index :kanban_calendar_external_busy_blocks,
              [:kanban_calendar_resource_id, :provider, :external_event_id],
              unique: true,
              name: 'idx_calendar_busy_blocks_on_resource_provider_event'
    remove_column :kanban_calendar_external_busy_blocks, :kanban_calendar_google_connection_id
  end

  def down
    add_reference :kanban_calendar_external_busy_blocks, :kanban_calendar_google_connection,
                  foreign_key: true, index: false
    remove_index :kanban_calendar_external_busy_blocks, name: 'idx_calendar_busy_blocks_on_resource_provider_event'
    add_index :kanban_calendar_external_busy_blocks,
              [:kanban_calendar_google_connection_id, :external_event_id],
              unique: true,
              name: 'idx_calendar_busy_blocks_on_connection_event'
    remove_column :kanban_calendar_external_busy_blocks, :provider
  end
end
