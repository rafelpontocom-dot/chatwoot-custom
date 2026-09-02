class AddMetaToDataImports < ActiveRecord::Migration[7.1]
  # Uma importação de oportunidades precisa de saber para que funil vai, qual a
  # etapa de recurso e como as colunas do ficheiro casam com os campos. Nada
  # disso cabe nas colunas que existiam, que só descreviam contactos.
  def change
    add_column :data_imports, :meta, :jsonb, default: {}, null: false
  end
end
