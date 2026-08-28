class CreateFormTemplates < ActiveRecord::Migration[7.1]
  def change
    create_form_templates
    create_form_template_versions
    add_reference :form_templates, :active_version, foreign_key: { to_table: :form_template_versions }
  end

  private

  def create_form_templates
    create_table :form_templates do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.string :category, null: false, default: 'lead_capture'
      t.string :access_classification, null: false, default: 'commercial'
      t.jsonb :settings, null: false, default: {}

      t.timestamps
    end
    add_index :form_templates, %i[account_id slug], unique: true
  end

  def create_form_template_versions
    create_table :form_template_versions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :form_template, null: false, foreign_key: true, index: false
      t.integer :version_number, null: false
      t.jsonb :schema, null: false, default: {}
      t.datetime :published_at, null: false

      t.timestamps
    end
    add_index :form_template_versions, %i[form_template_id version_number], unique: true,
                                                                            name: 'idx_form_template_versions_unique'
  end
end
