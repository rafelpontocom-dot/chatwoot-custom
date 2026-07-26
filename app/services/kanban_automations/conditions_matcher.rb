class KanbanAutomations::ConditionsMatcher
  SYSTEM_CHANGED_FIELD_KEYS = {
    'subject' => 'system_subject',
    'description' => 'system_description',
    'amount_cents' => 'system_amount',
    'amount_currency' => 'system_amount',
    'kanban_stage_id' => 'system_stage_id',
    'owner_id' => 'system_owner_id',
    'inbox_id' => 'system_inbox_id',
    'starts_at' => 'system_starts_at',
    'due_at' => 'system_due_at',
    'next_action_type' => 'system_next_action_type',
    'next_action_at' => 'system_next_action_at',
    'next_action_note' => 'system_next_action_note',
    'next_action_completed_at' => 'system_next_action_completed',
    'lost_reason' => 'system_lost_reason',
    'won_at' => 'system_status',
    'lost_at' => 'system_status',
    'contact_id' => 'system_contact_id',
    'conversation_id' => 'system_conversation_id'
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

  def initialize(rule:, card:, conditions: nil, event: nil, event_data: {})
    @rule = rule
    @card = card
    @conditions = conditions
    @event = event
    @event_data = event_data.to_h.with_indifferent_access
  end

  def matches?
    return false unless @rule.kanban_board_id == @card.kanban_board_id

    conditions = (@conditions.presence || @rule.trigger_conditions).to_h.with_indifferent_access
    base_conditions_match?(conditions) && changed_fields_match?(conditions[:changed_field_keys]) &&
      customer_message_matches?(conditions[:customer_message_contains]) &&
      field_conditions_match?(conditions[:fields])
  end

  def matches_field_condition?(condition)
    field_condition_matches?(condition)
  end

  private

  def ids_match?(expected_ids, actual_id)
    expected_ids = Array(expected_ids).filter_map { |value| Integer(value, exception: false) }
    expected_ids.blank? || expected_ids.include?(actual_id)
  end

  def base_conditions_match?(conditions)
    ids_match?(conditions[:inbox_ids], @card.inbox_id) &&
      ids_match?(conditions[:stage_ids], @card.kanban_stage_id) &&
      ids_match?(conditions[:owner_ids], @card.owner_id)
  end

  def field_conditions_match?(conditions)
    Array(conditions).all? { |condition| field_condition_matches?(condition) }
  end

  def changed_fields_match?(expected_keys)
    expected_keys = Array(expected_keys).map(&:to_s).reject(&:blank?)
    return true if expected_keys.blank?

    expected_keys.any? { |field_key| changed_field_keys.include?(field_key) }
  end

  def changed_field_keys
    changes = @event&.change_set.to_h.with_indifferent_access
    system_changed_field_keys(changes) + changed_custom_field_keys(changes)
  end

  def system_changed_field_keys(changes)
    SYSTEM_CHANGED_FIELD_KEYS.filter_map do |attribute, field_key|
      field_key if changes[attribute].present? && changes[attribute].first != changes[attribute].last
    end
  end

  def changed_custom_field_keys(changes)
    before, after = Array(changes[:custom_field_values])
    before = before.to_h.stringify_keys
    after = after.to_h.stringify_keys

    (before.keys | after.keys).reject { |key| before[key] == after[key] }
  end

  def customer_message_matches?(expected_phrase)
    return true if expected_phrase.blank?

    @event_data[:customer_message_content].to_s.downcase.include?(expected_phrase.to_s.downcase)
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
    KanbanAutomations::SystemFieldValues.new(card: @card).value(field_key)
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
    expected_present = expected.blank? || ActiveModel::Type::Boolean.new.cast(expected)
    value_present?(value) == expected_present
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
