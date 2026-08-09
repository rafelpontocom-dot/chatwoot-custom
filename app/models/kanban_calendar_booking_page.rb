class KanbanCalendarBookingPage < ApplicationRecord
  DUPLICATE_POLICIES = %w[create_new open_or_recent most_recent].freeze
  PUBLIC_FIELD_KINDS = %w[text date select].freeze

  belongs_to :account
  belongs_to :kanban_board, optional: true
  belongs_to :kanban_stage, optional: true
  belongs_to :inbox, optional: true
  has_many :kanban_calendar_booking_links, dependent: :destroy

  enum :duplicate_policy, DUPLICATE_POLICIES.index_by(&:itself), validate: true

  before_validation :ensure_public_token

  validates :public_token, presence: true, uniqueness: true
  validates :duplicate_policy, inclusion: { in: DUPLICATE_POLICIES }
  validates :minimum_notice_minutes, numericality: { only_integer: true, in: 0..525_600 }
  validates :maximum_notice_days, numericality: { only_integer: true, in: 1..730 }
  validates :slot_interval_minutes, inclusion: { in: [5, 10, 15, 20, 30, 60] }
  validates :captcha_provider, inclusion: { in: %w[turnstile], allow_blank: true }
  validates :captcha_site_key, presence: true, if: :captcha_provider?
  validate :public_form_fields_are_valid
  validate :crm_destination_belongs_to_account
  validate :stage_belongs_to_board
  validate :complete_crm_destination_when_active

  private

  def ensure_public_token
    self.public_token ||= SecureRandom.urlsafe_base64(24)
  end

  def crm_destination_belongs_to_account
    [kanban_board, kanban_stage, inbox].compact.each do |record|
      errors.add(:base, 'CRM destination must belong to the account') if record.account_id != account_id
    end
  end

  def stage_belongs_to_board
    return if kanban_board.blank? || kanban_stage.blank? || kanban_stage.kanban_board_id == kanban_board_id

    errors.add(:kanban_stage, 'must belong to the selected funnel')
  end

  def complete_crm_destination_when_active
    return unless active?
    return if kanban_board && kanban_stage && inbox

    errors.add(:base, 'Active booking pages need a funnel, stage, and inbox')
  end

  def captcha_provider?
    captcha_provider.present?
  end

  def public_form_fields_are_valid
    return if public_form_fields.all? { |field| valid_public_form_field?(field) }

    errors.add(:public_form_fields, 'must contain a key and label for each field')
  end

  def valid_public_form_field?(field)
    return false unless field.is_a?(Hash) && field['key'].to_s.match?(/\A[a-z][a-z0-9_]*\z/) && field['label'].present?
    return false unless PUBLIC_FIELD_KINDS.include?(field.fetch('kind', 'text'))

    field.fetch('kind', 'text') != 'select' || Array(field['options']).any?(&:present?)
  end
end
