class AddContactFieldKeysToKanbanBoards < ActiveRecord::Migration[7.1]
  # Quais atributos de contato aparecem na ficha, e em que ordem.
  #
  # A definição continua a ser do Chatwoot (`custom_attribute_definitions`); o
  # board guarda apenas a colocação. Sem esta camada a aba mostrava todo atributo
  # que existisse na conta — incluindo os técnicos do WAHA, como `waha_whatsapp_jid`,
  # que o comercial passava a ler como se fossem dados de negócio.
  #
  # Lista vazia significa "nunca configurado": a ficha cai no comportamento
  # anterior, mostrando o que tem valor preenchido.
  def change
    add_column :kanban_boards, :contact_field_keys, :jsonb, null: false, default: []
  end
end
