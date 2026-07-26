class KanbanAutomations::RuleConditionsValidator
  SUPPORTED_KEYS = %w[
    inbox_ids stage_ids owner_ids connection_ids fields changed_field_keys trigger_event_names customer_message_contains
  ].freeze

  def initialize(rule:)
    @rule = rule
  end

  def validate
    unsupported_keys
    unsupported_trigger_events
    field_conditions
  end

  private

  attr_reader :rule

  def source
    @source ||= rule.trigger_conditions
  end

  def unsupported_keys
    unsupported = source.keys.map(&:to_s) - SUPPORTED_KEYS
    rule.errors.add(:conditions, "Unsupported keys: #{unsupported.join(', ')}") if unsupported.present?
  end

  def unsupported_trigger_events
    return if KanbanAutomations::TriggerEvents.valid?(source[:trigger_event_names])

    rule.errors.add(:conditions, 'Trigger contains an unsupported event')
  end

  def field_conditions
    Array(source[:fields]).each_with_index do |condition, index|
      validate_field_condition(condition, index)
    end
  end

  def validate_field_condition(condition, index)
    condition = condition.to_h.with_indifferent_access
    rule.errors.add(:conditions, "Field condition #{index + 1} needs a field key") if condition[:field_key].blank?
    return if condition[:operator].blank? || KanbanAutomationRule::FIELD_OPERATORS.include?(condition[:operator].to_s)

    rule.errors.add(:conditions, "Field condition #{index + 1} has an unsupported operator")
  end
end
