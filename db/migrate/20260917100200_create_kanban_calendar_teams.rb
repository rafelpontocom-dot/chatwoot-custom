# Equipe: profissionais que atendem o mesmo procedimento. É o que permite
# oferecer «qualquer um que tenha vaga» ou distribuir por rodízio.
class CreateKanbanCalendarTeams < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_calendar_teams do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.string :assignment_strategy, null: false, default: 'first_available'
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :kanban_calendar_teams, 'account_id, lower((name)::text)',
              unique: true, name: 'index_calendar_teams_on_account_and_lower_name'

    create_table :kanban_calendar_team_members do |t|
      t.references :kanban_calendar_team, null: false, foreign_key: true, index: true
      t.references :kanban_calendar_resource, null: false, foreign_key: true, index: true
      t.boolean :active, null: false, default: true
      # O rodízio escolhe o membro livre que recebeu consulta há mais tempo.
      t.datetime :last_assigned_at
      t.timestamps
    end
    add_index :kanban_calendar_team_members, %i[kanban_calendar_team_id kanban_calendar_resource_id],
              unique: true, name: 'index_calendar_team_members_on_team_and_resource'

    add_reference :kanban_calendar_procedures, :kanban_calendar_team, foreign_key: true, index: true
  end
end
