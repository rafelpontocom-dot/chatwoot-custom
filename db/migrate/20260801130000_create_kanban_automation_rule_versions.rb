class CreateKanbanAutomationRuleVersions < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_automation_rule_versions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :kanban_automation_rule, null: false, foreign_key: true, index: false
      t.integer :version_number, null: false
      t.jsonb :snapshot, null: false, default: {}
      t.timestamps

      t.index %i[kanban_automation_rule_id version_number], unique: true, name: 'idx_kanban_rule_versions_unique'
    end
  end
end
