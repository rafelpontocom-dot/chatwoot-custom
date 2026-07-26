# == Schema Information
#
# Table name: kanban_automation_rules
#
#  id                 :bigint           not null, primary key
#  actions            :jsonb            not null
#  active             :boolean          default(TRUE), not null
#  conditions         :jsonb            not null
#  description        :text
#  event_name         :string           not null
#  flow_definition    :jsonb            not null
#  lock_version       :integer          default(0), not null
#  name               :string           not null
#  position           :integer          default(0), not null
#  reentry_enabled    :boolean          default(FALSE), not null
#  round_robin_cursor :integer          default(0), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  kanban_board_id    :bigint           not null
#
# Indexes
#
#  idx_kanban_automation_rules_board_name            (kanban_board_id,name) UNIQUE
#  idx_kanban_automation_rules_lookup                (account_id,kanban_board_id,event_name,active)
#  index_kanban_automation_rules_on_account_id       (account_id)
#  index_kanban_automation_rules_on_kanban_board_id  (kanban_board_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (kanban_board_id => kanban_boards.id)
#
class KanbanAutomationRule < ApplicationRecord
  EVENT_NAMES = [
    Events::Types::KANBAN_CARD_CREATED,
    Events::Types::KANBAN_CARD_STAGE_CHANGED,
    Events::Types::KANBAN_CARD_OWNER_CHANGED,
    Events::Types::KANBAN_CARD_AMOUNT_CHANGED,
    Events::Types::KANBAN_CARD_CUSTOM_FIELDS_CHANGED,
    Events::Types::KANBAN_CARD_NEXT_ACTION_SCHEDULED,
    Events::Types::KANBAN_CARD_NEXT_ACTION_COMPLETED, Events::Types::KANBAN_CARD_NEXT_ACTION_OVERDUE,
    Events::Types::KANBAN_CARD_WON,
    Events::Types::KANBAN_CARD_LOST,
    Events::Types::KANBAN_CARD_REOPENED,
    Events::Types::KANBAN_CARD_ARCHIVED,
    Events::Types::KANBAN_CARD_RESTORED,
    Events::Types::KANBAN_CARD_MANUAL_STARTED,
    Events::Types::KANBAN_CARD_CUSTOMER_MESSAGE_RECEIVED,
    Events::Types::KANBAN_CARD_WEBHOOK_RECEIVED
  ].freeze
  FIELD_OPERATORS = %w[equals not_equals contains exists greater_than greater_or_equal less_than less_or_equal].freeze
  ACTION_NAMES = %w[
    move_stage assign_owner assign_round_robin set_next_action complete_next_action
    mark_won mark_lost set_field increment_field clear_field update_contact archive_card
    enroll_cadence add_label remove_label add_note
  ].freeze
  FLOW_NODE_TYPES = %w[
    trigger delay wait_until_field wait_for_response wait_for_inactivity wait_for_business_hours
    send_message action set_field update_contact complete_next_action mark_won mark_lost
    condition filter message_eligibility round_robin human_handoff audit_log webhook end
  ].freeze
  belongs_to :account
  belongs_to :kanban_board
  has_many :kanban_automation_executions, dependent: :destroy
  has_many :kanban_automation_rule_versions, dependent: :destroy
  scope :active, -> { where(active: true) }
  scope :for_event, ->(event_name) { where(event_name: event_name) }
  scope :ordered, -> { order(position: :asc, id: :asc) }
  validates :name, presence: true, uniqueness: { scope: :kanban_board_id }
  validates :event_name, inclusion: { in: EVENT_NAMES }
  validates :account, :kanban_board, presence: true
  before_validation :reset_round_robin_cursor, if: :will_save_change_to_flow_definition?
  validate :board_belongs_to_account
  validate :conditions_are_supported
  validate :actions_are_supported
  validate :references_belong_to_board
  validate :flow_definition_is_supported

  def trigger_conditions
    conditions.to_h.with_indifferent_access
  end

  def visual_flow?
    flow_definition.to_h['nodes'].present?
  end

  def version_number
    lock_version + 1
  end

  def version_snapshot
    attributes.slice(
      'name',
      'description',
      'event_name',
      'active',
      'reentry_enabled',
      'position',
      'conditions',
      'actions',
      'flow_definition'
    )
  end

  def record_version!
    kanban_automation_rule_versions.create!(
      account: account,
      version_number: version_number,
      snapshot: version_snapshot
    )
  end

  def restore_version!(version)
    update!(version.snapshot.slice(*version_snapshot.keys))
    record_version!
  end

  private

  def board_belongs_to_account
    return if account.blank? || kanban_board.blank?
    return if account_id == kanban_board.account_id

    errors.add(:kanban_board, :invalid)
  end

  def reset_round_robin_cursor
    self.round_robin_cursor = 0
  end

  def conditions_are_supported
    source = trigger_conditions
    unsupported = source.keys.map(&:to_s) - %w[inbox_ids stage_ids owner_ids fields changed_field_keys]
    errors.add(:conditions, "Unsupported keys: #{unsupported.join(', ')}") if unsupported.present?

    Array(source[:fields]).each_with_index do |condition, index|
      validate_field_condition(condition, index)
    end
  end

  def validate_field_condition(condition, index)
    source = condition.to_h.with_indifferent_access
    errors.add(:conditions, "Field condition #{index + 1} needs a field key") if source[:field_key].blank?
    return if source[:operator].blank? || FIELD_OPERATORS.include?(source[:operator].to_s)

    errors.add(:conditions, "Field condition #{index + 1} has an unsupported operator")
  end

  def actions_are_supported
    Array(actions).each_with_index do |action, index|
      action_name = action.to_h.with_indifferent_access[:action_name].to_s
      next if ACTION_NAMES.include?(action_name)

      errors.add(:actions, "Action #{index + 1} is not supported")
    end
  end

  def references_belong_to_board
    return if kanban_board.blank? || account.blank?

    validate_condition_references
    validate_action_references
  end

  def validate_condition_references
    conditions = trigger_conditions
    validate_reference_ids(conditions[:stage_ids], kanban_board.kanban_stages, :stage_ids)
    validate_reference_ids(conditions[:inbox_ids], account.inboxes, :inbox_ids)
    validate_reference_ids(conditions[:owner_ids], account.users, :owner_ids)

    Array(conditions[:fields]).each do |condition|
      validate_field_reference(condition.to_h.with_indifferent_access[:field_key])
    end
    Array(conditions[:changed_field_keys]).each do |field_key|
      validate_changed_field_reference(field_key)
    end
  end

  def validate_action_references
    Array(actions).each do |action|
      source = action.to_h.with_indifferent_access
      params = source[:action_params].to_h.with_indifferent_access
      validate_action_stage(source, params)
      validate_action_owner(source, params)
      validate_action_round_robin(source, params)
      validate_action_field(source, params)
      validate_action_cadence(source, params)
    end
  end

  def validate_action_stage(source, params)
    return unless source[:action_name].to_s == 'move_stage'

    validate_reference_ids([params[:stage_id]], kanban_board.kanban_stages, :actions)
  end

  def validate_action_owner(source, params)
    return unless source[:action_name].to_s == 'assign_owner'

    validate_reference_ids([params[:owner_id]], account.users, :actions)
  end

  def validate_action_round_robin(source, params)
    return unless source[:action_name].to_s == 'assign_round_robin'

    validate_reference_ids(params[:owner_ids], account.users, :actions)
    errors.add(:actions, 'Round-robin needs at least one owner') if Array(params[:owner_ids]).blank?
  end

  def validate_action_field(source, params)
    return unless %w[set_field increment_field].include?(source[:action_name].to_s)

    validate_field_reference(params[:field_key], attribute: :actions)
  end

  def validate_action_cadence(source, params)
    return unless source[:action_name].to_s == 'enroll_cadence'

    validate_reference_ids([params[:cadence_id]], kanban_board.kanban_cadences.active, :actions)
  end

  def validate_reference_ids(ids, relation, attribute)
    Array(ids).filter_map { |value| Integer(value, exception: false) }.each do |id|
      errors.add(attribute, "Reference #{id} does not belong to this board") unless relation.exists?(id: id)
    end
  end

  def validate_field_reference(field_key, attribute: :conditions)
    return if field_key.blank?
    return if KanbanCard::SYSTEM_CONDITION_VALUE_METHODS.key?(field_key.to_s)
    return if kanban_board.configured_custom_field_definitions.any? { |field| field['key'] == field_key.to_s }

    errors.add(attribute, "Field #{field_key} does not belong to this board")
  end

  def validate_changed_field_reference(field_key)
    return if field_key.blank?
    return if kanban_board.configured_custom_field_definitions.any? { |field| field['key'] == field_key.to_s }

    errors.add(:conditions, "Field #{field_key} does not belong to this board")
  end

  def flow_definition_is_supported
    KanbanAutomations::FlowDefinitionValidator.new(rule: self).validate
  end
end
