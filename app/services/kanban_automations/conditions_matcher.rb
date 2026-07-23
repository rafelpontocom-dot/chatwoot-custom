class KanbanAutomations::ConditionsMatcher
  SYSTEM_FIELD_METHODS = {
    'system_subject' => :system_subject,
    'system_description' => :system_description,
    'system_amount' => :system_amount,
    'system_owner_id' => :system_owner_id,
    'system_stage_id' => :system_stage_id,
    'system_inbox_id' => :system_inbox_id,
    'system_status' => :system_status,
    'system_starts_at' => :system_starts_at,
    'system_due_at' => :system_due_at,
    'system_next_action_type' => :system_next_action_type,
    'system_next_action_at' => :system_next_action_at,
    'system_next_action_note' => :system_next_action_note,
    'system_next_action_completed' => :system_next_action_completed,
    'system_lost_reason' => :system_lost_reason,
    'system_contact_id' => :system_contact_id,
    'system_conversation_id' => :system_conversation_id
  }.freeze
  FIELD_OPERATOR_HANDLERS = {
    'equals' => :matches_equality?,
    'not_equals' => :matches_inequality?,
    'contains' => :matches_contains?,
    'exists' => :matches_existence?,
    'greater_than' => :matches_greater_than?,
    'greater_or_equal' => :matches_greater_or_equal?,
    'less_than' => :matches_less_than?,
    'less_or_equal' => :matches_less_or_equal?
  }.freeze

  def initialize(rule:, card:)
    @rule = rule
    @card = card
  end

  def matches?
    return false unless @rule.kanban_board_id == @card.kanban_board_id

    conditions = @rule.trigger_conditions
    ids_match?(conditions[:inbox_ids], @card.inbox_id) &&
      ids_match?(conditions[:stage_ids], @card.kanban_stage_id) &&
      ids_match?(conditions[:owner_ids], @card.owner_id) &&
      Array(conditions[:fields]).all? { |condition| field_condition_matches?(condition) }
  end

  def matches_field_condition?(condition)
    field_condition_matches?(condition)
  end

  private

  def ids_match?(expected_ids, actual_id)
    expected_ids = Array(expected_ids).filter_map { |value| Integer(value, exception: false) }
    expected_ids.blank? || expected_ids.include?(actual_id)
  end

  def field_condition_matches?(condition)
    source = condition.to_h.with_indifferent_access
    value = field_value(source[:field_key].to_s)
    operator = source[:operator].presence || 'equals'
    expected = source[:value]

    handler = FIELD_OPERATOR_HANDLERS[operator]
    handler && send(handler, value, expected)
  end

  def field_value(field_key)
    return @card.custom_field_values.to_h[field_key] unless field_key.start_with?('system_')

    system_field_value(field_key)
  end

  def system_field_value(field_key)
    method_name = SYSTEM_FIELD_METHODS[field_key]
    method_name && send(method_name)
  end

  def system_subject
    @card.subject
  end

  def system_description
    @card.description
  end

  def system_amount
    @card.amount_cents && (@card.amount_cents.to_f / 100)
  end

  def system_owner_id
    @card.owner_id
  end

  def system_stage_id
    @card.kanban_stage_id
  end

  def system_inbox_id
    @card.inbox_id
  end

  def system_status
    return 'open' if @card.open_opportunity?

    @card.won_at.present? ? 'won' : 'lost'
  end

  def system_starts_at
    @card.starts_at
  end

  def system_due_at
    @card.due_at
  end

  def system_next_action_type
    @card.next_action_type
  end

  def system_next_action_at
    @card.next_action_at
  end

  def system_next_action_note
    @card.next_action_note
  end

  def system_next_action_completed
    @card.next_action_completed_at.present?
  end

  def system_lost_reason
    @card.lost_reason
  end

  def system_contact_id
    @card.contact_id
  end

  def system_conversation_id
    @card.conversation_id
  end

  def matches_equality?(value, expected)
    comparable_value(value) == comparable_value(expected)
  end

  def matches_inequality?(value, expected)
    comparable_value(value) != comparable_value(expected)
  end

  def matches_contains?(value, expected)
    value.is_a?(Array) ? value.include?(expected) : value.to_s.downcase.include?(expected.to_s.downcase)
  end

  def matches_existence?(value, expected)
    value_present?(value) == ActiveModel::Type::Boolean.new.cast(expected)
  end

  def matches_greater_than?(value, expected)
    compare(value, expected).positive?
  end

  def matches_greater_or_equal?(value, expected)
    compare(value, expected) >= 0
  end

  def matches_less_than?(value, expected)
    compare(value, expected).negative?
  end

  def matches_less_or_equal?(value, expected)
    compare(value, expected) <= 0
  end

  def contains?(value, expected)
    return value.include?(expected) if value.is_a?(Array)

    value.to_s.downcase.include?(expected.to_s.downcase)
  end

  def value_present?(value)
    value.present? || value == false
  end

  def comparable_value(value)
    return value.map(&:to_s).sort if value.is_a?(Array)
    return value.to_f if value.is_a?(Numeric)

    value.to_s
  end

  def compare(value, expected)
    numeric_value = Float(value)
    numeric_expected = Float(expected)
    numeric_value <=> numeric_expected
  rescue ArgumentError, TypeError
    value.to_s <=> expected.to_s
  end
end
