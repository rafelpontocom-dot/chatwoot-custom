# == Schema Information
#
# Table name: kanban_calendar_procedures
#
#  id                          :bigint           not null, primary key
#  active                      :boolean          default(TRUE), not null
#  allowed_intervals           :jsonb            not null
#  assignment_strategy         :string           default("patient_choice"), not null
#  availability_mode           :string           default("resources"), not null
#  board_ids                   :jsonb            not null
#  buffer_after_minutes        :integer          default(0), not null
#  buffer_before_minutes       :integer          default(0), not null
#  cancel_allowed              :boolean          default(TRUE), not null
#  cancel_reason_required      :boolean          default(TRUE), not null
#  change_deadline_hours       :integer          default(12), not null
#  color                       :string
#  daily_limit                 :integer
#  deposit_cents               :integer
#  duration_minutes            :integer          not null
#  hold_minutes                :integer          default(10), not null
#  location_type               :string           default("in_person"), not null
#  max_sessions                :integer
#  maximum_notice_days         :integer
#  minimum_notice_minutes      :integer
#  name                        :string           not null
#  on_cancel_stage_action      :string           default("back_to_scheduling"), not null
#  payment_enabled             :boolean          default(FALSE), not null
#  payment_methods             :jsonb            not null
#  payment_mode                :string           default("full"), not null
#  price_cents                 :integer
#  public_booking_config       :jsonb            not null
#  public_booking_enabled      :boolean          default(FALSE), not null
#  public_description          :text
#  public_slug                 :string
#  public_title                :string
#  recurrence_allowed          :boolean          default(FALSE), not null
#  reschedule_allowed          :boolean          default(TRUE), not null
#  slot_interval_minutes       :integer
#  stage_policy                :jsonb            not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  account_id                  :bigint           not null
#  kanban_calendar_schedule_id :bigint
#  kanban_calendar_team_id     :bigint
#
# Indexes
#
#  idx_on_kanban_calendar_schedule_id_ac12f1ba93                (kanban_calendar_schedule_id)
#  index_calendar_procedures_on_account_and_public_slug         (account_id, lower((public_slug)::text)) UNIQUE WHERE (public_slug IS NOT NULL)
#  index_kanban_calendar_procedures_on_account_and_lower_name   (account_id, lower((name)::text)) UNIQUE
#  index_kanban_calendar_procedures_on_account_id               (account_id)
#  index_kanban_calendar_procedures_on_kanban_calendar_team_id  (kanban_calendar_team_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (kanban_calendar_schedule_id => kanban_calendar_schedules.id)
#  fk_rails_...  (kanban_calendar_team_id => kanban_calendar_teams.id)
#
class KanbanCalendarProcedure < ApplicationRecord
  LOCATION_TYPES = %w[in_person video phone other].freeze
  INTERVAL_KINDS = %w[weekly biweekly monthly].freeze
  AVAILABILITY_MODES = %w[resources schedule].freeze
  ASSIGNMENT_STRATEGIES = %w[patient_choice first_available round_robin collective].freeze
  TEAM_STRATEGIES = %w[first_available round_robin].freeze
  PAYMENT_MODES = %w[full deposit].freeze
  PAYMENT_METHODS = %w[pix card on_site].freeze
  CANCEL_STAGE_ACTIONS = %w[back_to_scheduling mark_lost none].freeze
  QUESTION_KINDS = %w[text phone email cpf textarea select date].freeze
  # O que a página pergunta quando o procedimento ainda não escolheu. Nome é fixo;
  # CPF só é obrigatório quando alguma agenda do procedimento espelha no Feegow.
  DEFAULT_QUESTIONS = [
    { 'key' => 'full_name', 'label' => 'Nome completo', 'kind' => 'text', 'required' => true, 'locked' => true },
    { 'key' => 'whatsapp', 'label' => 'WhatsApp', 'kind' => 'phone', 'required' => true },
    { 'key' => 'cpf', 'label' => 'CPF', 'kind' => 'cpf', 'required' => 'feegow' },
    { 'key' => 'email', 'label' => 'E-mail', 'kind' => 'email', 'required' => false },
    { 'key' => 'notes', 'label' => 'Algo que a equipe deva saber?', 'kind' => 'textarea', 'required' => false }
  ].freeze

  belongs_to :account
  # Horário próprio do procedimento, quando `availability_mode` é `schedule`.
  belongs_to :kanban_calendar_schedule, optional: true
  # Equipe que atende, quando a estratégia é primeiro com vaga ou rodízio.
  belongs_to :kanban_calendar_team, optional: true

  has_many :kanban_calendar_procedure_resources, dependent: :destroy
  has_many :kanban_calendar_resources, through: :kanban_calendar_procedure_resources
  has_many :kanban_calendar_appointment_series, dependent: :restrict_with_error
  has_many :kanban_calendar_appointments, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :account_id, case_sensitive: false }
  validates :duration_minutes, numericality: { only_integer: true, in: 5..480 }
  validates :buffer_before_minutes, :buffer_after_minutes, numericality: { only_integer: true, in: 0..120 }
  validates :location_type, inclusion: { in: LOCATION_TYPES }
  validates :max_sessions, numericality: { only_integer: true, in: 1..100 }, if: :recurrence_allowed?
  validates :public_slug,
            format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ },
            allow_blank: true
  validates :public_slug, presence: true, if: :public_booking_enabled?
  validate :max_sessions_absent_without_recurrence
  validate :allowed_intervals_are_supported
  validates :availability_mode, inclusion: { in: AVAILABILITY_MODES }
  validates :kanban_calendar_schedule, presence: true, if: -> { availability_mode == 'schedule' }
  validates :assignment_strategy, inclusion: { in: ASSIGNMENT_STRATEGIES }
  validates :kanban_calendar_team, presence: true, if: -> { assignment_strategy.in?(TEAM_STRATEGIES) }
  validates :minimum_notice_minutes, numericality: { only_integer: true, in: 0..525_600 }, allow_nil: true
  validates :maximum_notice_days, numericality: { only_integer: true, in: 1..730 }, allow_nil: true
  validates :slot_interval_minutes, inclusion: { in: KanbanCalendarResource::SLOT_INTERVAL_MINUTES }, allow_nil: true
  validates :daily_limit, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :payment_mode, inclusion: { in: PAYMENT_MODES }
  validates :price_cents, numericality: { only_integer: true, greater_than: 0 }, if: :payment_enabled?
  validates :hold_minutes, numericality: { only_integer: true, in: 5..60 }
  validates :change_deadline_hours, numericality: { only_integer: true, in: 0..720 }
  validates :on_cancel_stage_action, inclusion: { in: CANCEL_STAGE_ACTIONS }
  validate :deposit_is_less_than_price
  validate :payment_methods_are_supported
  validate :schedule_and_team_belong_to_account
  validate :booking_questions_are_valid

  scope :active, -> { where(active: true) }

  def booking_questions
    questions = public_booking_config.is_a?(Hash) ? public_booking_config['questions'] : nil
    questions.presence || DEFAULT_QUESTIONS
  end

  # CPF entra quando o prontuário exige: alguma agenda do procedimento espelha no Feegow.
  def mirrors_feegow?
    kanban_calendar_resources.any? { |resource| resource.settings.dig('feegow', 'professional_id').present? }
  end

  private

  def deposit_is_less_than_price
    return unless payment_enabled? && payment_mode == 'deposit'
    return if deposit_cents.to_i.positive? && price_cents.present? && deposit_cents < price_cents

    errors.add(:deposit_cents, 'must be greater than zero and less than the price')
  end

  def payment_methods_are_supported
    return if payment_methods.is_a?(Array) && payment_methods.any? && (payment_methods - PAYMENT_METHODS).empty?

    errors.add(:payment_methods, 'must be a non-empty subset of pix, card and on_site')
  end

  def schedule_and_team_belong_to_account
    [kanban_calendar_schedule, kanban_calendar_team].compact.each do |record|
      errors.add(:base, 'Schedule and team must belong to the account') if record.account_id != account_id
    end
  end

  def booking_questions_are_valid
    questions = public_booking_config.is_a?(Hash) ? public_booking_config['questions'] : nil
    return if questions.nil?
    return if questions.is_a?(Array) && questions.all? { |question| valid_question?(question) } && full_name_question_kept?(questions)

    errors.add(:public_booking_config, 'questions must have a key, a label, a supported kind and keep the full name')
  end

  def valid_question?(question)
    return false unless question.is_a?(Hash) && question['key'].to_s.match?(/\A[a-z][a-z0-9_]*\z/) && question['label'].present?

    valid_question_kind?(question)
  end

  def valid_question_kind?(question)
    return false unless question['kind'].in?(QUESTION_KINDS) && question['required'].in?([true, false, 'feegow'])

    question['kind'] != 'select' || Array(question['options']).any?(&:present?)
  end

  def full_name_question_kept?(questions)
    questions.any? { |question| question['key'] == 'full_name' && question['required'] == true }
  end

  def max_sessions_absent_without_recurrence
    return if recurrence_allowed? || max_sessions.blank?

    errors.add(:max_sessions, 'must be blank when recurrence is disabled')
  end

  def allowed_intervals_are_supported
    return if allowed_intervals.all? { |interval| interval.in?(INTERVAL_KINDS) || interval.to_s.match?(/\Adays:\d+\z/) }

    errors.add(:allowed_intervals, 'contains an unsupported interval')
  end
end
