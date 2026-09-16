# == Schema Information
#
# Table name: kanban_calendar_resources
#
#  id                    :bigint           not null, primary key
#  active                :boolean          default(TRUE), not null
#  capacity              :integer          default(1), not null
#  name                  :string           not null
#  resource_type         :string           not null
#  settings              :jsonb            not null
#  slot_interval_minutes :integer
#  timezone              :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#  user_id               :bigint
#
# Indexes
#
#  index_kanban_calendar_resources_on_account_and_user  (account_id,user_id) UNIQUE WHERE (user_id IS NOT NULL)
#  index_kanban_calendar_resources_on_account_id        (account_id)
#  index_kanban_calendar_resources_on_user_id           (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (user_id => users.id)
#
class KanbanCalendarResource < ApplicationRecord
  RESOURCE_TYPES = %w[user room equipment generic].freeze
  SLOT_INTERVAL_MINUTES = [5, 10, 15, 20, 30, 60].freeze
  # Agenda sem janela de trabalho não oferece horário nenhum. Nascer com a
  # semana comercial é o que a torna utilizável no minuto a seguir a ser criada;
  # quem atende noutro horário muda em Agendas › Horários.
  DEFAULT_WORKING_DAYS = (1..5)
  DEFAULT_WORKING_HOURS = { starts_at_local: '08:00', ends_at_local: '18:00' }.freeze

  belongs_to :account
  belongs_to :user, optional: true

  has_many :kanban_calendar_procedure_resources, dependent: :destroy
  has_many :kanban_calendar_procedures, through: :kanban_calendar_procedure_resources
  has_many :kanban_calendar_appointment_resources, dependent: :restrict_with_error
  has_many :kanban_calendar_appointments, through: :kanban_calendar_appointment_resources
  has_many :kanban_calendar_availability_rules, dependent: :destroy
  has_one :kanban_calendar_google_connection, dependent: :destroy
  has_many :kanban_calendar_external_busy_blocks, dependent: :destroy

  validates :name, :timezone, presence: true
  validates :resource_type, inclusion: { in: RESOURCE_TYPES }
  validates :capacity, numericality: { only_integer: true, equal_to: 1 }
  # Nulo é «o padrão da conta», que vem da página de agendamento.
  validates :slot_interval_minutes, inclusion: { in: SLOT_INTERVAL_MINUTES }, allow_nil: true
  # O tipo `user` é o profissional, e já não exige utilizador do CRM: quem
  # atende na clínica pode não ter login. A ligação a um utilizador continua
  # possível, e continua a ter de ser da mesma conta.
  validate :user_belongs_to_account
  validate :valid_timezone

  scope :active, -> { where(active: true) }

  after_create :create_default_working_hours

  private

  def create_default_working_hours
    return if kanban_calendar_availability_rules.any?

    DEFAULT_WORKING_DAYS.each do |weekday|
      kanban_calendar_availability_rules.create!(kind: 'weekly_window', weekday: weekday, **DEFAULT_WORKING_HOURS)
    end
  end

  def user_belongs_to_account
    return if user.blank? || user.account_ids.include?(account_id)

    errors.add(:user, 'must belong to the account')
  end

  def valid_timezone
    return if timezone.blank? || TZInfo::Timezone.get(timezone)
  rescue TZInfo::InvalidTimezoneIdentifier
    errors.add(:timezone, 'must be a valid IANA timezone')
  end
end
