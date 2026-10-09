class AddVisibilityToLabels < ActiveRecord::Migration[7.1]
  # As etiquetas que já existem nascem TODAS `global` (2), por decisão do Pedro em
  # 07/10: a migração não esconde nada de ninguém e nenhuma etiqueta desaparece da
  # vista de quem a usa hoje. É a única escolha que não quebra operação em curso.
  #
  # O `default` também protege os caminhos que criam etiqueta sem passar pela tela
  # (automações, importação, API antiga): sem visibilidade declarada, a etiqueta é
  # de todos, como era antes desta coluna existir.
  #
  # SEM chave estrangeira em `created_by_id` e `team_id`, de propósito, pelo mesmo
  # motivo que a `macros` — que é o modelo que o Pedro mandou seguir — também não
  # tem: uma chave RESTRICT passaria a IMPEDIR apagar um utilizador ou um time que
  # tivesse criado uma etiqueta. O preço é um órfão possível (autor ou time que já
  # não existe), tratado na visibilidade e registado como limite conhecido.
  def change
    add_column :labels, :visibility, :integer, null: false, default: 2
    add_column :labels, :created_by_id, :bigint
    add_column :labels, :team_id, :bigint
    add_index :labels, :created_by_id
    add_index :labels, :team_id
  end
end
