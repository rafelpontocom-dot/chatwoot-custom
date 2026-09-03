class CreateMarketingTouchpoints < ActiveRecord::Migration[7.1]
  # Um toque e uma vez em que soubemos de onde alguem veio.
  #
  # Nao vive no contato porque a atribuicao precisa sobreviver ao contato: a
  # oportunidade e apagada, a conversa e apagada, e a historia de onde o lead
  # veio continua a valer para o relatorio. Dai as FKs anularem em vez de
  # cascatearem.
  def change
    create_table :marketing_touchpoints do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, foreign_key: { on_delete: :nullify }
      t.references :conversation, foreign_key: { on_delete: :nullify }
      t.references :kanban_card, foreign_key: { on_delete: :nullify }
      t.string :source, null: false
      t.jsonb :payload, null: false, default: {}
      t.datetime :occurred_at, null: false
      # o mesmo evento chegando duas vezes e um no-op, nao uma linha nova
      t.string :dedupe_digest, null: false

      t.timestamps
    end

    add_index :marketing_touchpoints, [:account_id, :dedupe_digest], unique: true,
                                                                     name: 'index_marketing_touchpoints_on_account_and_digest'
    add_index :marketing_touchpoints, [:account_id, :occurred_at]
    add_index :marketing_touchpoints, [:account_id, :contact_id, :occurred_at],
              name: 'index_marketing_touchpoints_on_account_contact_and_time'
    add_index :marketing_touchpoints, [:account_id, :source, :occurred_at],
              name: 'index_marketing_touchpoints_on_account_source_and_time'
  end
end
