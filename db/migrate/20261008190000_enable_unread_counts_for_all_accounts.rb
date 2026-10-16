# RAEVO (08/10, 123jpnbc242): o Pedro pediu o número de conversas por ler ao lado
# de Conversas e no ícone da guia. O Chatwoot já o calcula e mantém em tempo real
# — contas, caixas, etiquetas, times, menções —, atrás destas duas flags, que
# nascem desligadas (`config/features.yml`, `chatwoot_internal`). Liga-se em todas
# as contas que existem; uma conta nova liga-se no Super Admin › Contas › Features.
class EnableUnreadCountsForAllAccounts < ActiveRecord::Migration[7.1]
  FEATURES = %w[conversation_unread_counts unread_count_for_filters].freeze

  def up
    Account.find_each { |account| account.enable_features!(*FEATURES) }
  end

  def down
    Account.find_each { |account| account.disable_features!(*FEATURES) }
  end
end
