class CreateMarketingLeadForms < ActiveRecord::Migration[7.1]
  # O formulario do Meta como ele e la: pagina, id do formulario e as perguntas
  # tal como o anunciante as escreveu. O mapeamento para o CRM fica ao lado, no
  # mesmo contrato que o Forms ja usa (`crm_destination`).
  def change
    create_table :marketing_lead_forms do |t|
      t.references :account, null: false, foreign_key: true
      t.references :marketing_provider_connection, null: false, foreign_key: true,
                                                   index: { name: 'index_marketing_lead_forms_on_connection' }
      t.string :page_id, null: false
      t.string :page_name
      t.string :external_form_id, null: false
      t.string :name
      t.jsonb :questions, null: false, default: []
      t.jsonb :field_mapping, null: false, default: {}
      t.jsonb :crm_destination, null: false, default: {}
      t.boolean :active, null: false, default: false
      t.datetime :last_synced_at
      t.datetime :last_lead_at
      t.integer :received_count, null: false, default: 0

      t.timestamps
    end

    add_index :marketing_lead_forms, [:account_id, :external_form_id], unique: true,
                                                                       name: 'index_marketing_lead_forms_on_account_and_form'
  end
end
