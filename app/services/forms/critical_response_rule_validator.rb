class Forms::CriticalResponseRuleValidator
  attr_reader :errors

  def initialize(form_template)
    @form_template = form_template
    @errors = []
  end

  def valid?
    return true if form_template.sensitive_health? || rule.blank? || disabled?

    validate_presence
    validate_published_field if errors.empty?
    validate_selection_value if errors.empty?
    errors.empty?
  end

  private

  attr_reader :form_template

  def rule
    @rule ||= form_template.critical_response_rule
  end

  def disabled?
    rule['field_key'].blank? && rule['value'].blank?
  end

  def validate_presence
    return unless rule.values_at('field_key', 'value').any?(&:blank?)

    errors << 'critical response requires a question and value'
  end

  def validate_published_field
    return if field.present?

    errors << 'critical response must reference a published question'
  end

  def validate_selection_value
    return unless Forms::SchemaValidator::SELECTION_TYPES.include?(field['type'])
    return if field_options.map(&:to_s).include?(rule['value'].to_s)

    errors << 'critical response value must be a published option'
  end

  def field
    @field ||= published_fields.find { |candidate| candidate['key'].to_s == rule['field_key'].to_s }
  end

  def published_fields
    return [] unless form_template.active_version

    form_template.active_version.schema.fetch('sections', []).flat_map { |section| section.fetch('fields', []) }
  end

  def field_options
    Array(field['options']).map do |option|
      option.is_a?(Hash) ? option['value'] || option[:value] : option
    end
  end
end
