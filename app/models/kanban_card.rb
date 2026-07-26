# rubocop:disable Metrics/ClassLength
# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: kanban_cards
#
#  id                       :bigint           not null, primary key
#  active                   :boolean          default(TRUE), not null
#  amount_cents             :bigint
#  amount_currency          :string           default("BRL"), not null
#  archived_at              :datetime
#  custom_field_values      :jsonb            not null
#  description              :text
#  due_at                   :datetime
#  expected_close_date      :date
#  lock_version             :integer          default(0), not null
#  lost_at                  :datetime
#  lost_reason              :string
#  next_action_at           :datetime
#  next_action_completed_at :datetime
#  next_action_history      :jsonb            not null
#  next_action_note         :text
#  next_action_type         :string
#  normalized_subject       :string
#  origin                   :string           not null
#  position                 :integer          default(0), not null
#  stage_entered_at         :datetime         not null
#  starts_at                :datetime
#  subject                  :string
#  won_at                   :datetime
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :bigint           not null
#  archived_by_id           :bigint
#  closed_by_id             :bigint
#  contact_id               :bigint           not null
#  conversation_id          :bigint
#  inbox_id                 :bigint           not null
#  kanban_board_id          :bigint           not null
#  kanban_stage_id          :bigint           not null
#  owner_id                 :bigint
#
# Indexes
#
#  index_active_kanban_cards_on_board_stage_order                 (kanban_board_id,kanban_stage_id,position,created_at,id) WHERE (active = true)
#  index_active_manual_kanban_cards_unique_subject                (kanban_board_id,contact_id,inbox_id,normalized_subject) UNIQUE WHERE ((active = true) AND ((origin)::text = 'manual'::text) AND (normalized_subject IS NOT NULL))
#  index_kanban_cards_on_account_id_and_active                    (account_id,active)
#  index_kanban_cards_on_account_id_and_contact_id                (account_id,contact_id)
#  index_kanban_cards_on_account_id_and_inbox_id                  (account_id,inbox_id)
#  index_kanban_cards_on_account_id_and_next_action_at            (account_id,next_action_at)
#  index_kanban_cards_on_archived_by_id                           (archived_by_id)
#  index_kanban_cards_on_board_stage_position                     (kanban_board_id,kanban_stage_id,position)
#  index_kanban_cards_on_conversation_id                          (conversation_id)
#  index_kanban_cards_on_conversation_subject_unique              (kanban_board_id,conversation_id,inbox_id,normalized_subject) UNIQUE WHERE (((origin)::text = 'conversation'::text) AND (conversation_id IS NOT NULL) AND (normalized_subject IS NOT NULL))
#  index_kanban_cards_on_kanban_board_id_and_active               (kanban_board_id,active)
#  index_kanban_cards_on_kanban_board_id_and_amount_cents         (kanban_board_id,amount_cents)
#  index_kanban_cards_on_kanban_board_id_and_archived_at          (kanban_board_id,archived_at)
#  index_kanban_cards_on_kanban_board_id_and_expected_close_date  (kanban_board_id,expected_close_date)
#  index_kanban_cards_on_kanban_board_id_and_lost_at              (kanban_board_id,lost_at)
#  index_kanban_cards_on_kanban_board_id_and_next_action_at       (kanban_board_id,next_action_at)
#  index_kanban_cards_on_kanban_board_id_and_won_at               (kanban_board_id,won_at)
#  index_kanban_cards_on_owner_id_and_next_action_at              (owner_id,next_action_at)
#
# Foreign Keys
#
#  fk_rails_...  (archived_by_id => users.id)
#
# rubocop:enable Layout/LineLength
class KanbanCard < ApplicationRecord
  include Labelable

  NEXT_ACTION_STATUS_CLOSED = 'closed'.freeze
  NEXT_ACTION_STATUS_DUE_TODAY = 'due_today'.freeze
  NEXT_ACTION_STATUS_FUTURE = 'future'.freeze
  NEXT_ACTION_STATUS_MISSING = 'missing'.freeze
  NEXT_ACTION_STATUS_OVERDUE = 'overdue'.freeze
  FORMULA_FIELD_PATTERN = /[a-zA-Z_][a-zA-Z0-9_]*/
  FORMULA_TOKEN_PATTERN = %r{\d+(?:\.\d+)?|[+\-*/()]}
  DATE_FORMULA_PATTERN = /
    \A(?<function>add_days|days_between)\(
    \s*(?<left>[a-zA-Z_][a-zA-Z0-9_]*)
    \s*,\s*(?<right>-?\d+(?:\.\d+)?|[a-zA-Z_][a-zA-Z0-9_]*)
    \s*\)\z
  /x
  NUMERIC_CUSTOM_FIELD_TYPES = %w[integer decimal currency formula].freeze
  SYSTEM_AMOUNT_FIELD_KEY = 'system_amount'.freeze
  SYSTEM_CONDITION_VALUE_METHODS = {
    'system_subject' => :subject,
    'system_description' => :description,
    SYSTEM_AMOUNT_FIELD_KEY => :opportunity_amount,
    'system_owner_id' => :owner_id,
    'system_assignee_id' => :conversation_assignee_id,
    'system_stage_id' => :kanban_stage_id,
    'system_inbox_id' => :inbox_id,
    'system_status' => :opportunity_status,
    'system_starts_at' => :condition_starts_on,
    'system_due_at' => :condition_due_on,
    'system_next_action_type' => :next_action_type,
    'system_next_action_at' => :condition_next_action_on,
    'system_next_action_note' => :next_action_note,
    'system_next_action_completed' => :next_action_completed_for_condition?,
    'system_lost_reason' => :lost_reason,
    'system_contact_id' => :contact_id,
    'system_conversation_id' => :conversation_id
  }.freeze
  EVENT_ATTRIBUTE_GROUPS = {
    'stage_changed' => %w[kanban_stage_id],
    'owner_changed' => %w[owner_id],
    'amount_changed' => %w[amount_cents amount_currency],
    'custom_fields_changed' => %w[custom_field_values],
    'next_action_scheduled' => %w[next_action_type next_action_at next_action_note],
    'next_action_completed' => %w[next_action_completed_at],
    'card_won' => %w[won_at],
    'card_lost' => %w[lost_at lost_reason],
    'card_archived' => %w[archived_at],
    'card_restored' => %w[active]
  }.freeze

  belongs_to :account
  belongs_to :kanban_board
  belongs_to :kanban_stage
  belongs_to :contact
  belongs_to :inbox
  belongs_to :conversation, optional: true
  belongs_to :owner, class_name: 'User', optional: true
  belongs_to :closed_by, class_name: 'User', optional: true
  belongs_to :archived_by, class_name: 'User', optional: true

  attr_accessor :next_action_completion_note

  has_many :kanban_card_events, dependent: :restrict_with_exception
  has_many :kanban_cadence_enrollments, dependent: :destroy

  enum :origin, {
    conversation: 'conversation',
    manual: 'manual'
  }

  before_validation :normalize_subject
  before_validation :normalize_blank_description
  before_validation :normalize_blank_sales_fields
  before_validation :reset_next_action_completion, if: :next_action_details_changed?
  before_validation :append_next_action_history, if: :next_action_completion_changed?
  before_validation :set_stage_entered_at, if: :stage_entry_timestamp_required?
  after_create :record_creation_event
  after_update :record_commercial_events

  validates :origin, presence: true
  validates :position, presence: true, numericality: { only_integer: true }
  validates :stage_entered_at, presence: true
  validates :subject, presence: true, if: :manual?
  validates :normalized_subject, presence: true, if: :manual?
  validates :conversation, presence: true, if: :conversation?
  validates :normalized_subject,
            uniqueness: {
              scope: [:kanban_board_id, :contact_id, :inbox_id],
              conditions: -> { where(active: true, origin: 'manual') }
            },
            if: :validate_manual_uniqueness?
  validates :conversation_id,
            uniqueness: {
              scope: [:kanban_board_id, :inbox_id, :normalized_subject],
              conditions: -> { where(origin: 'conversation').where.not(normalized_subject: nil) }
            },
            if: :validate_conversation_uniqueness?
  validate :due_at_after_starts_at
  validate :lost_reason_present_when_lost
  validate :won_and_lost_are_mutually_exclusive
  validate :required_custom_fields_present
  validate :validate_account_consistency

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(position: :asc, created_at: :asc, id: :asc) }
  scope :open_opportunities, -> { active.where(won_at: nil, lost_at: nil) }

  def self.normalize_positions_for_stage!(kanban_board:, kanban_stage:)
    transaction do
      stage_active_cards(kanban_board, kanban_stage).lock.pluck(:id)
      bulk_normalize_positions_for_stage!(kanban_board, kanban_stage)
    end
  end

  def reorder_to_position!(kanban_stage:, position:)
    raise ActiveRecord::RecordNotSaved, 'Inactive kanban cards cannot be reordered' unless active?

    self.class.transaction do
      source_stage = self.kanban_stage
      stage_ids = [source_stage.id, kanban_stage.id].uniq.sort

      self.class.lock_reorder_stages!(stage_ids)
      self.class.lock_active_cards_for_stages!(kanban_board, stage_ids)

      normalize_reorder_stages!(source_stage, kanban_stage)
      reload

      if source_stage == kanban_stage
        reorder_within_stage!(kanban_stage, position)
      else
        reorder_across_stages!(source_stage, kanban_stage, position)
      end

      normalize_reorder_stages!(source_stage, kanban_stage)
      record_stage_change_event(source_stage, kanban_stage)
      reload
    end
  end

  def deactivate_and_normalize!
    archive!
  end

  def archive!(actor: nil)
    self.class.transaction do
      stage = kanban_stage

      self.class.lock_reorder_stages!([stage.id])
      self.class.lock_active_cards_for_stages!(kanban_board, [stage.id])

      @event_actor = actor
      update!(active: false, archived_at: Time.current, archived_by: actor)
      self.class.normalize_positions_for_stage!(kanban_board: kanban_board, kanban_stage: stage)
      reload
    end
  end

  def restore!(actor: nil)
    @event_actor = actor
    update!(
      active: true,
      archived_at: nil,
      archived_by: nil,
      position: self.class.where(kanban_board: kanban_board, kanban_stage: kanban_stage).active.maximum(:position).to_i + 1
    )
  end

  def self.stage_active_cards(kanban_board, kanban_stage)
    where(kanban_board: kanban_board, kanban_stage: kanban_stage).active.ordered
  end

  def open_opportunity?
    active? && won_at.blank? && lost_at.blank?
  end

  def next_action_status(now: Time.current)
    return NEXT_ACTION_STATUS_CLOSED unless open_opportunity?
    return NEXT_ACTION_STATUS_MISSING if next_action_completed_at.present?
    return NEXT_ACTION_STATUS_MISSING if next_action_at.blank?

    next_action_date = next_action_at.in_time_zone.to_date
    current_date = now.in_time_zone.to_date

    return NEXT_ACTION_STATUS_OVERDUE if next_action_date < current_date
    return NEXT_ACTION_STATUS_DUE_TODAY if next_action_date == current_date

    NEXT_ACTION_STATUS_FUTURE
  end

  def stale_in_stage?(now: Time.current)
    threshold_days = kanban_board&.stale_days_for_stage(kanban_stage_id)
    return false if threshold_days.blank? || stage_entered_at.blank? || !open_opportunity?

    stage_entered_at <= threshold_days.days.ago(now)
  end

  def compact_custom_fields
    kanban_board.compact_custom_field_definitions.filter_map do |definition|
      value = custom_field_values.to_h[definition['key']]
      next if value.nil? || value == '' || value == []

      definition.slice('key', 'label', 'field_type').merge('value' => value)
    end
  end

  def missing_required_custom_field_keys
    custom_field_definitions.filter_map do |definition|
      next unless custom_field_required_for_stage?(definition)
      next unless custom_field_visible?(definition)

      value = custom_field_values.to_h[definition['key']]
      definition['key'] unless value == false || value.present?
    end
  end

  def self.lock_reorder_stages!(stage_ids)
    KanbanStage.where(id: stage_ids).order(:id).lock.each(&:id)
  end

  def self.lock_active_cards_for_stages!(kanban_board, stage_ids)
    where(kanban_board: kanban_board, kanban_stage_id: stage_ids).active.order(:kanban_stage_id, :position, :created_at, :id).lock.each(&:id)
  end

  def self.bulk_normalize_positions_for_stage!(kanban_board, kanban_stage)
    connection.execute(<<~SQL.squish)
      WITH ordered_cards AS (
        SELECT id, row_number() OVER (ORDER BY position ASC, created_at ASC, id ASC) AS normalized_position
        FROM #{quoted_table_name}
        WHERE kanban_board_id = #{connection.quote(kanban_board.id)}
          AND kanban_stage_id = #{connection.quote(kanban_stage.id)}
          AND active = TRUE
      )
      UPDATE #{quoted_table_name}
      SET position = ordered_cards.normalized_position,
          updated_at = #{connection.quote(Time.current)}
      FROM ordered_cards
      WHERE #{quoted_table_name}.id = ordered_cards.id
        AND #{quoted_table_name}.position != ordered_cards.normalized_position
    SQL
  end

  private_class_method :bulk_normalize_positions_for_stage!

  private

  def record_stage_change_event(source_stage, target_stage)
    return if source_stage == target_stage

    reload
    create_card_event!('stage_changed', 'kanban_stage_id' => [source_stage.id, target_stage.id])
  end

  def record_creation_event
    create_card_event!('card_created', {})
  end

  def record_commercial_events
    EVENT_ATTRIBUTE_GROUPS.each do |event_type, attributes|
      event_changes = saved_changes.slice(*attributes)
      next if event_changes.blank?
      next unless event_matches_current_state?(event_type)

      create_card_event!(event_type, event_changes)
    end

    record_reopened_event if reopened_by_last_change?
  ensure
    @event_actor = nil
  end

  def record_reopened_event
    create_card_event!('card_reopened', saved_changes.slice('won_at', 'lost_at'))
  end

  def reopened_by_last_change?
    return false if won_at.present? || lost_at.present?

    %w[won_at lost_at].any? do |attribute|
      previous_value, current_value = saved_changes[attribute]
      previous_value.present? && current_value.blank?
    end
  end

  def event_matches_current_state?(event_type)
    case event_type
    when 'card_won' then won_at.present?
    when 'card_lost' then lost_at.present?
    when 'card_archived' then archived_at.present?
    when 'card_restored' then active?
    else true
    end
  end

  def create_card_event!(event_type, event_changes)
    kanban_card_events.create!(
      account: account,
      kanban_board: kanban_board,
      event_type: event_type,
      actor: @event_actor || Current.user,
      occurred_at: Time.current,
      change_set: event_changes,
      metadata: {}
    )
  end

  def normalize_reorder_stages!(source_stage, target_stage)
    self.class.normalize_positions_for_stage!(kanban_board: kanban_board, kanban_stage: source_stage)
    return if source_stage == target_stage

    self.class.normalize_positions_for_stage!(kanban_board: kanban_board, kanban_stage: target_stage)
  end

  def reorder_within_stage!(target_stage, target_position)
    cards = stage_active_cards_without_self(target_stage)
    cards.insert(clamped_position(target_position, cards.length + 1) - 1, self)

    update_stage_positions!(cards, target_stage)
  end

  def reorder_across_stages!(source_stage, target_stage, target_position)
    source_cards = stage_active_cards_without_self(source_stage)
    destination_cards = self.class.stage_active_cards(kanban_board, target_stage).to_a

    update_stage_positions!(source_cards, source_stage)

    destination_cards.insert(clamped_position(target_position, destination_cards.length + 1) - 1, self)
    update_stage_positions!(destination_cards, target_stage)
  end

  def stage_active_cards_without_self(stage)
    self.class.stage_active_cards(kanban_board, stage).where.not(id: id).to_a
  end

  def clamped_position(target_position, maximum_position)
    target_position.to_i.clamp(1, maximum_position)
  end

  def update_stage_positions!(cards, target_stage)
    changed_cards = cards.each_with_index.filter_map do |card, index|
      position = index + 1
      next if card.position == position && card.kanban_stage_id == target_stage.id

      [card.id, position, card.kanban_stage_id != target_stage.id]
    end

    return if changed_cards.blank?

    # rubocop:disable Rails/SkipsModelValidations
    self.class.where(id: changed_cards.map(&:first)).update_all(bulk_position_update_sql(changed_cards, target_stage))
    # rubocop:enable Rails/SkipsModelValidations
  end

  def bulk_position_update_sql(changed_cards, target_stage)
    current_time = self.class.connection.quote(Time.current)
    position_cases = changed_cards.map { |card_id, position, _stage_changed| "WHEN #{card_id} THEN #{position}" }.join(' ')
    stage_cases = changed_cards.map { |card_id, _position, _stage_changed| "WHEN #{card_id} THEN #{target_stage.id}" }.join(' ')
    stage_entered_at_cases = changed_cards.filter_map do |card_id, _position, stage_changed|
      "WHEN #{card_id} THEN #{current_time}" if stage_changed
    end.join(' ')

    <<~SQL.squish
      position = CASE id #{position_cases} ELSE position END,
      kanban_stage_id = CASE id #{stage_cases} ELSE kanban_stage_id END,
      #{stage_entered_at_update_sql(stage_entered_at_cases)}
      updated_at = #{current_time}
    SQL
  end

  def stage_entered_at_update_sql(stage_entered_at_cases)
    return 'stage_entered_at = stage_entered_at,' if stage_entered_at_cases.blank?

    "stage_entered_at = CASE id #{stage_entered_at_cases} ELSE stage_entered_at END,"
  end

  def normalize_subject
    self.normalized_subject = nil

    normalized_display_subject = subject.to_s.strip.gsub(/\s+/, ' ')
    self.subject = normalized_display_subject.presence
    self.normalized_subject = normalized_display_subject.presence&.downcase
  end

  def normalize_blank_description
    self.description = nil if description.blank?
  end

  def normalize_blank_sales_fields
    self.next_action_type = nil if next_action_type.blank?
    self.next_action_note = nil if next_action_note.blank?
    self.lost_reason = nil if lost_reason.blank?
    self.amount_currency = 'BRL' if amount_currency.blank?
    self.custom_field_values = normalized_custom_field_values
  end

  def normalized_custom_field_values
    values = custom_field_values.to_h.with_indifferent_access
    normalized_values = {}

    custom_field_definitions.each do |definition|
      key = definition['key']
      next if definition['field_type'] == 'formula'

      normalized_value = normalize_custom_field_value(definition, values[key])
      normalized_values[key] = normalized_value unless normalized_value.nil?
    end

    custom_field_definitions.select { |definition| definition['field_type'] == 'formula' }.each do |definition|
      formula_value = calculate_formula_value(definition, normalized_values)
      normalized_values[definition['key']] = formula_value unless formula_value.nil?
    end

    normalized_values
  end

  def custom_field_definitions
    kanban_board&.configured_custom_field_definitions || []
  end

  def stage_entry_timestamp_required?
    new_record? || will_save_change_to_kanban_stage_id?
  end

  def set_stage_entered_at
    self.stage_entered_at = Time.current
  end

  def validate_manual_uniqueness?
    active? && manual? && normalized_subject.present?
  end

  def validate_conversation_uniqueness?
    conversation? && conversation_id.present? && normalized_subject.present?
  end

  def due_at_after_starts_at
    return if starts_at.blank? || due_at.blank? || due_at >= starts_at

    errors.add(:due_at, 'must be greater than or equal to starts at')
  end

  def lost_reason_present_when_lost
    return if lost_at.blank? || lost_reason.present?

    errors.add(:lost_reason, :blank)
  end

  def won_and_lost_are_mutually_exclusive
    return if won_at.blank? || lost_at.blank?

    errors.add(:base, 'cannot be marked as won and lost at the same time')
  end

  def required_custom_fields_present
    missing_required_custom_field_keys.each do |field_key|
      errors.add(:custom_field_values, "#{field_key} is required")
    end
  end

  def custom_field_required_for_stage?(definition)
    Array(definition['required_stage_ids']).map(&:to_i).include?(kanban_stage_id)
  end

  def custom_field_visible?(definition)
    condition = definition['condition'].to_h
    return true if condition.blank?

    condition_field_value_matches?(condition['field_key'], condition['equals'])
  end

  def condition_field_value_matches?(field_key, expected_value)
    actual_value = condition_field_value(field_key)
    return false if actual_value.nil?

    return BigDecimal(actual_value.to_s) == BigDecimal(expected_value.to_s) if numeric_condition_field?(field_key)

    actual_value.to_s == expected_value.to_s
  rescue ArgumentError
    false
  end

  def condition_field_value(field_key)
    values = custom_field_values.to_h
    return values[field_key] if values.key?(field_key)

    value_method = SYSTEM_CONDITION_VALUE_METHODS[field_key]
    send(value_method) if value_method
  end

  def numeric_condition_field?(field_key)
    return true if field_key == SYSTEM_AMOUNT_FIELD_KEY

    definition = custom_field_definitions.find { |item| item['key'] == field_key }
    definition && NUMERIC_CUSTOM_FIELD_TYPES.include?(definition['field_type'])
  end

  def opportunity_amount
    return if amount_cents.nil?

    amount_cents.to_d / 100
  end

  def opportunity_status
    return 'won' if won_at.present?
    return 'lost' if lost_at.present?

    'open'
  end

  def conversation_assignee_id
    conversation&.assignee_id
  end

  def condition_starts_on
    starts_at&.in_time_zone&.to_date&.iso8601
  end

  def condition_due_on
    due_at&.in_time_zone&.to_date&.iso8601
  end

  def condition_next_action_on
    next_action_at&.in_time_zone&.to_date&.iso8601
  end

  def next_action_completed_for_condition?
    next_action_completed_at.present?
  end

  def normalize_custom_field_value(definition, value)
    return if value.nil? || (value != false && value.respond_to?(:blank?) && value.blank?)

    custom_field_value_normalizer(definition).call(value)
  rescue ArgumentError, TypeError, URI::InvalidURIError
    errors.add(:custom_field_values, "#{definition['key']} is invalid")
    nil
  end

  def custom_field_value_normalizer(definition)
    normalizers = {
      'integer' => method(:normalize_integer_custom_field_value),
      'decimal' => method(:normalize_decimal_custom_field_value),
      'currency' => method(:normalize_decimal_custom_field_value),
      'boolean' => method(:normalize_boolean_custom_field_value),
      'select' => ->(value) { normalize_select_custom_field_value(definition, value) },
      'multiselect' => ->(value) { normalize_multiselect_custom_field_value(definition, value) },
      'date' => method(:normalize_date_custom_field_value),
      'datetime' => method(:normalize_datetime_custom_field_value),
      'url' => method(:normalize_url_custom_field_value)
    }

    normalizers.fetch(definition['field_type'], method(:normalize_text_custom_field_value))
  end

  def normalize_integer_custom_field_value(value)
    Integer(value)
  end

  def normalize_decimal_custom_field_value(value)
    Float(value)
  end

  def normalize_boolean_custom_field_value(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end

  def normalize_text_custom_field_value(value)
    value.to_s.strip.presence
  end

  def normalize_date_custom_field_value(value)
    Date.iso8601(value.to_s).iso8601
  end

  def normalize_datetime_custom_field_value(value)
    Time.zone.parse(value.to_s)&.iso8601
  end

  def normalize_select_custom_field_value(definition, value)
    normalized_value = value.to_s.strip
    return normalized_value if Array(definition['options']).include?(normalized_value)

    errors.add(:custom_field_values, "#{definition['key']} is invalid")
    nil
  end

  def normalize_multiselect_custom_field_value(definition, value)
    normalized_values = Array(value).filter_map { |item| item.to_s.strip.presence }.uniq
    return normalized_values if (normalized_values - Array(definition['options'])).empty?

    errors.add(:custom_field_values, "#{definition['key']} is invalid")
    nil
  end

  def normalize_url_custom_field_value(value)
    normalized_value = value.to_s.strip
    uri = URI.parse(normalized_value)
    return normalized_value if uri.is_a?(URI::HTTP) && uri.host.present?

    raise URI::InvalidURIError
  end

  def next_action_completion_changed?
    next_action_completed_at.present? && will_save_change_to_next_action_completed_at?
  end

  def next_action_details_changed?
    will_save_change_to_next_action_type? || will_save_change_to_next_action_at? || will_save_change_to_next_action_note?
  end

  def reset_next_action_completion
    return if new_record? || will_save_change_to_next_action_completed_at?

    self.next_action_completed_at = nil
  end

  def append_next_action_history
    entry = {
      'type' => next_action_type,
      'scheduled_at' => next_action_at&.iso8601(3),
      'note' => next_action_note,
      'completed_at' => next_action_completed_at.iso8601(3)
    }
    entry['completion_note'] = next_action_completion_note if next_action_completion_note.present?
    self.next_action_history = [*Array(next_action_history), entry].last(100)
  end

  def calculate_formula_value(definition, values)
    formula = definition['formula'].to_s
    return if formula.blank?

    return calculate_date_formula_value(definition, formula, values) if formula.match?(DATE_FORMULA_PATTERN)

    raise ArgumentError unless definition['formula_result_type'].to_s.in?(['', 'number'])

    expression = formula_expression_with_values(formula, values)
    return if expression.blank?

    evaluate_formula_expression(expression).to_f
  rescue ArgumentError, ZeroDivisionError, SyntaxError
    errors.add(:custom_field_values, "#{definition['key']} formula is invalid")
    nil
  end

  def calculate_date_formula_value(definition, formula, values)
    match = DATE_FORMULA_PATTERN.match(formula)
    raise ArgumentError unless match

    case match[:function]
    when 'add_days'
      calculate_add_days_formula(definition, match[:left], match[:right], values)
    when 'days_between'
      raise ArgumentError unless definition['formula_result_type'].to_s.in?(['', 'number'])

      (formula_date_value(match[:right], values) - formula_date_value(match[:left], values)).to_i.to_f
    end
  end

  def calculate_add_days_formula(definition, field_key, days_token, values)
    result_type = definition['formula_result_type'].presence || 'date'
    raise ArgumentError unless %w[date datetime].include?(result_type)

    days = formula_numeric_token_value(days_token, values).to_i
    source_definition = formula_field_definition(field_key)
    raise ArgumentError unless %w[date datetime].include?(source_definition&.dig('field_type'))

    if result_type == 'datetime' || source_definition['field_type'] == 'datetime'
      formula_datetime_value(field_key, values).advance(days: days).iso8601
    else
      (formula_date_value(field_key, values) + days).iso8601
    end
  end

  def formula_numeric_token_value(token, values)
    return Float(token) if token.match?(/\A-?\d+(?:\.\d+)?\z/)

    definition = numeric_formula_field_definition!(formula_field_definition(token))
    ensure_calculated_formula_value!(definition, token, values)
    Float(values[token] || 0)
  end

  def formula_date_value(field_key, values)
    definition = formula_field_definition(field_key)
    raise ArgumentError unless %w[date datetime].include?(definition&.dig('field_type'))

    return Date.iso8601(values.fetch(field_key).to_s) if definition['field_type'] == 'date'

    formula_datetime_value(field_key, values).to_date
  end

  def formula_datetime_value(field_key, values)
    zone = ActiveSupport::TimeZone[account&.reporting_timezone] || Time.zone
    zone.parse(values.fetch(field_key).to_s)&.in_time_zone(zone) || raise(ArgumentError)
  end

  def formula_field_definition(field_key)
    custom_field_definitions.find { |field_definition| field_definition['key'] == field_key }
  end

  def formula_expression_with_values(formula, values)
    definitions_by_key = custom_field_definitions.index_by { |field_definition| field_definition['key'] }
    formula.gsub(FORMULA_FIELD_PATTERN) do |field_key|
      formula_field_value(field_key, definitions_by_key, values)
    end
  end

  def formula_field_value(field_key, definitions_by_key, values)
    return (opportunity_amount || 0).to_d.to_s('F') if field_key == SYSTEM_AMOUNT_FIELD_KEY

    field_definition = numeric_formula_field_definition!(definitions_by_key[field_key])
    ensure_calculated_formula_value!(field_definition, field_key, values)

    Float(values[field_key] || 0).to_s
  end

  def numeric_formula_field_definition!(field_definition)
    raise ArgumentError if field_definition.blank?
    raise ArgumentError unless NUMERIC_CUSTOM_FIELD_TYPES.include?(field_definition['field_type'])

    field_definition
  end

  def ensure_calculated_formula_value!(field_definition, field_key, values)
    return unless field_definition['field_type'] == 'formula'
    raise ArgumentError unless values.key?(field_key)
  end

  def evaluate_formula_expression(expression)
    normalized_expression = expression.delete(' ').tr(',', '.')
    tokens = normalized_expression.scan(FORMULA_TOKEN_PATTERN)
    raise ArgumentError if tokens.join != normalized_expression

    result = parse_formula_expression(tokens)
    raise ArgumentError if tokens.any?

    result
  end

  def parse_formula_expression(tokens)
    value = parse_formula_term(tokens)

    while %w[+ -].include?(tokens.first)
      operator = tokens.shift
      next_value = parse_formula_term(tokens)
      value = operator == '+' ? value + next_value : value - next_value
    end

    value
  end

  def parse_formula_term(tokens)
    value = parse_formula_factor(tokens)

    while %w[* /].include?(tokens.first)
      operator = tokens.shift
      next_value = parse_formula_factor(tokens)
      value = operator == '*' ? value * next_value : value / next_value
    end

    value
  end

  def parse_formula_factor(tokens)
    token = tokens.shift
    raise ArgumentError if token.blank?
    return -parse_formula_factor(tokens) if token == '-'

    return parse_parenthesized_formula_expression(tokens) if token == '('
    return Float(token) if token.match?(/\A\d+(?:\.\d+)?\z/)

    raise ArgumentError
  end

  def parse_parenthesized_formula_expression(tokens)
    value = parse_formula_expression(tokens)
    raise ArgumentError unless tokens.shift == ')'

    value
  end

  def validate_account_consistency
    validate_account_for(:kanban_board)
    validate_account_for(:kanban_stage)
    validate_account_for(:contact)
    validate_account_for(:inbox)
    validate_account_for(:conversation)
    validate_board_for_stage
    validate_conversation_contact
    validate_conversation_inbox
  end

  def validate_account_for(association_name)
    associated_record = public_send(association_name)
    return if associated_record.blank? || associated_record.account_id == account_id

    errors.add(association_name, :invalid)
  end

  def validate_board_for_stage
    return if kanban_stage.blank? || kanban_board.blank? || kanban_stage.kanban_board_id == kanban_board_id

    errors.add(:kanban_stage, :invalid)
  end

  def validate_conversation_contact
    return if conversation.blank? || contact.blank? || conversation.contact_id == contact_id

    errors.add(:conversation, :invalid)
  end

  def validate_conversation_inbox
    return if conversation.blank? || inbox.blank? || conversation.inbox_id == inbox_id

    errors.add(:conversation, :invalid)
  end
end
# rubocop:enable Metrics/ClassLength
