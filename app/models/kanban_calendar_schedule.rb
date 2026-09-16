# == Schema Information
#
# Table name: kanban_calendar_schedules
#
#  id                           :bigint           not null, primary key
#  default_schedule             :boolean          default(FALSE), not null
#  name                         :string           not null
#  timezone                     :string           not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  account_id                   :bigint           not null
#  kanban_calendar_procedure_id :bigint
#
# Indexes
#
#  idx_on_kanban_calendar_procedure_id_82f1544c94      (kanban_calendar_procedure_id)
#  index_calendar_schedules_on_account_and_lower_name  (account_id, lower((name)::text)) UNIQUE WHERE (kanban_calendar_procedure_id IS NULL)
#  index_calendar_schedules_on_account_default         (account_id) UNIQUE WHERE (default_schedule = true)
#  index_kanban_calendar_schedules_on_account_id       (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (kanban_calendar_procedure_id => kanban_calendar_procedures.id)
#
# Horário com nome («Comercial», «Manhãs da Dra. Anna»), que várias agendas
# usam. Mudar o horário uma vez muda todas as agendas que o usam.
#
# Um horário com procedimento é privado desse procedimento («horário só deste
# procedimento») e não aparece na lista da conta.
class KanbanCalendarSchedule < ApplicationRecord
  belongs_to :account
  belongs_to :kanban_calendar_procedure, optional: true

  has_many :kanban_calendar_availability_rules, dependent: :destroy
  has_many :kanban_calendar_resources, dependent: :restrict_with_error
  has_many :kanban_calendar_procedures, dependent: :nullify

  validates :name, :timezone, presence: true
  validates :name, uniqueness: { scope: :account_id, case_sensitive: false }, unless: :kanban_calendar_procedure_id?
  validate :valid_timezone
  validate :procedure_belongs_to_account

  scope :shared, -> { where(kanban_calendar_procedure_id: nil) }

  # Só um horário padrão por conta: marcar este desmarca o anterior.
  before_save :release_previous_default, if: -> { default_schedule? && will_save_change_to_default_schedule? }

  def working_hours?
    kanban_calendar_availability_rules.active.exists?(kind: %w[weekly_window date_override])
  end

  private

  def release_previous_default
    account.kanban_calendar_schedules.where(default_schedule: true).where.not(id: id).update_all(default_schedule: false) # rubocop:disable Rails/SkipsModelValidations
  end

  def valid_timezone
    return if timezone.blank? || TZInfo::Timezone.get(timezone)
  rescue TZInfo::InvalidTimezoneIdentifier
    errors.add(:timezone, 'must be a valid IANA timezone')
  end

  def procedure_belongs_to_account
    return if kanban_calendar_procedure.blank? || kanban_calendar_procedure.account_id == account_id

    errors.add(:kanban_calendar_procedure, 'must belong to the account')
  end
end
