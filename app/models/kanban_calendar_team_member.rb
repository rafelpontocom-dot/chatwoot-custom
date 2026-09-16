# == Schema Information
#
# Table name: kanban_calendar_team_members
#
#  id                          :bigint           not null, primary key
#  active                      :boolean          default(TRUE), not null
#  last_assigned_at            :datetime
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  kanban_calendar_resource_id :bigint           not null
#  kanban_calendar_team_id     :bigint           not null
#
# Indexes
#
#  idx_on_kanban_calendar_resource_id_6412b830fd                  (kanban_calendar_resource_id)
#  index_calendar_team_members_on_team_and_resource               (kanban_calendar_team_id,kanban_calendar_resource_id) UNIQUE
#  index_kanban_calendar_team_members_on_kanban_calendar_team_id  (kanban_calendar_team_id)
#
# Foreign Keys
#
#  fk_rails_...  (kanban_calendar_resource_id => kanban_calendar_resources.id)
#  fk_rails_...  (kanban_calendar_team_id => kanban_calendar_teams.id)
#
class KanbanCalendarTeamMember < ApplicationRecord
  belongs_to :kanban_calendar_team
  belongs_to :kanban_calendar_resource

  validates :kanban_calendar_resource_id, uniqueness: { scope: :kanban_calendar_team_id }
  validate :member_is_a_professional_of_the_account

  scope :active, -> { where(active: true) }

  private

  # Equipe é de quem atende: sala e equipamento entram no procedimento, não aqui.
  def member_is_a_professional_of_the_account
    resource = kanban_calendar_resource
    return if resource.blank?

    errors.add(:kanban_calendar_resource, 'must be a professional') unless resource.resource_type == 'user'
    errors.add(:kanban_calendar_resource, 'must belong to the account') if resource.account_id != kanban_calendar_team&.account_id
  end
end
