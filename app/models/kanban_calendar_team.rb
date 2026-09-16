# == Schema Information
#
# Table name: kanban_calendar_teams
#
#  id                  :bigint           not null, primary key
#  active              :boolean          default(TRUE), not null
#  assignment_strategy :string           default("first_available"), not null
#  name                :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#
# Indexes
#
#  index_calendar_teams_on_account_and_lower_name  (account_id, lower((name)::text)) UNIQUE
#  index_kanban_calendar_teams_on_account_id       (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
# A estratégia decide quem fica com a consulta quando o paciente não escolhe:
# `first_available` oferece o horário livre de qualquer membro, `round_robin`
# distribui por igual, `collective` exige todos livres ao mesmo tempo.
class KanbanCalendarTeam < ApplicationRecord
  ASSIGNMENT_STRATEGIES = %w[first_available round_robin collective].freeze

  belongs_to :account

  has_many :kanban_calendar_team_members, dependent: :destroy
  has_many :kanban_calendar_resources, through: :kanban_calendar_team_members
  has_many :kanban_calendar_procedures, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :account_id, case_sensitive: false }
  validates :assignment_strategy, inclusion: { in: ASSIGNMENT_STRATEGIES }

  scope :active, -> { where(active: true) }

  def active_resources
    kanban_calendar_resources.merge(KanbanCalendarTeamMember.active).where(kanban_calendar_resources: { active: true })
  end
end
