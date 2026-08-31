class Forms::SchemaValidator
  FIELD_TYPES = %w[
    text textarea email phone number currency date datetime select multi_select checkbox consent signature attachment hidden
  ].freeze
  SELECTION_TYPES = %w[select multi_select].freeze
  SECTION_LAYOUTS = %w[single two_columns].freeze
  OPPORTUNITY_POLICIES = %w[create_new reuse_open].freeze
  KEY_PATTERN = /\A[a-z][a-z0-9_]*\z/

  attr_reader :errors

  def initialize(
    schema = nil,
    require_public_contact_mapping: false,
    require_crm_destination: false,
    sensitive_health: false,
    **schema_keywords
  )
    @schema = (schema || schema_keywords).to_h
    @require_public_contact_mapping = require_public_contact_mapping
    @require_crm_destination = require_crm_destination
    # `sensitive_health` é uma bandeira só: era `allow_attachments` em paralelo,
    # mas os dois valiam sempre o mesmo — anexo clínico e classificação clínica
    # são a mesma decisão vista de dois lados.
    @sensitive_health = sensitive_health
    @errors = []
  end

  def valid?
    validate_schema unless @validated
    errors.empty?
  end

  private

  def validate_schema
    @validated = true
    sections = @schema['sections']
    return errors << 'must include at least one section' unless sections.is_a?(Array) && sections.present?

    section_keys = []
    field_keys = []
    sections.each do |section|
      validate_section(section, section_keys, field_keys)
    end
    validate_condition_references(field_keys)
    validate_logic(field_keys)
    validate_submission_actions
    validate_crm_destination
    validate_opportunity_mapping(field_keys)
    validate_public_contact_mapping(field_keys)
  end

  def validate_section(section, section_keys, field_keys)
    section = section.to_h
    key = section['key'].to_s
    unless key.match?(KEY_PATTERN) && section['fields'].is_a?(Array)
      errors << 'sections must define a key and fields'
      return
    end

    errors << 'section keys must be unique' if section_keys.include?(key)
    section_keys << key
    validate_section_layout(section['layout'])
    validate_content_blocks(section['content_blocks'])
    section['fields'].each { |field| validate_field(field, field_keys) }
  end

  def validate_section_layout(layout)
    return if layout.blank? || SECTION_LAYOUTS.include?(layout)

    errors << 'sections must use a supported layout'
  end

  def validate_content_blocks(blocks)
    return if Forms::SchemaContentValidator.new(blocks: blocks).valid?

    errors << 'content blocks must use safe supported content'
  end

  def validate_field(field, field_keys)
    field = field.to_h
    key = field['key'].to_s
    type = field['type'].to_s
    unless key.match?(KEY_PATTERN) && field['label'].present? && FIELD_TYPES.include?(type)
      errors << 'fields must define a key, label, and supported type'
      return
    end

    errors << 'field keys must be unique' if field_keys.include?(key)
    field_keys << key
    field_types[key] = type
    validate_attachment_field(type)
    errors << 'selection fields must include options' if SELECTION_TYPES.include?(type) && invalid_options?(field['options'])
    validate_condition(field)
  end

  def validate_attachment_field(type)
    return unless type == 'attachment' && !@sensitive_health

    errors << 'attachment fields require a private clinical form'
  end

  def invalid_options?(options)
    !options.is_a?(Array) || options.empty? || options.any? { |option| option_value(option).blank? }
  end

  def option_value(option)
    option.is_a?(Hash) ? option['value'] || option[:value] : option
  end

  def validate_condition(field)
    condition = field['visible_when']
    return if condition.blank?

    condition = condition.to_h
    if condition['field'].to_s.match?(KEY_PATTERN) && condition['operator'] == 'equals' && condition.key?('value')
      conditional_field_references << condition['field']
      return
    end

    errors << 'conditional fields must use a supported condition'
  end

  # Guardado por chave para o validador de lógica saber que operadores cabem
  # em cada pergunta: «maior que» não faz sentido numa assinatura.
  def field_types
    @field_types ||= {}
  end

  # O que acontece depois da resposta também é assunto próprio.
  def validate_submission_actions
    validator = Forms::SubmissionActionsValidator.new(
      schema: @schema,
      sensitive_health: @sensitive_health
    )
    errors.concat(validator.errors)
  end

  # Lógica é um assunto próprio, com regras próprias; vive na sua classe para
  # este validador continuar a tratar só de estrutura.
  def validate_logic(field_keys)
    validator = Forms::LogicValidator.new(schema: @schema, field_keys: field_keys, field_types: field_types)
    errors.concat(validator.errors)
  end

  def validate_condition_references(field_keys)
    return if conditional_field_references.all? { |reference| field_keys.include?(reference) }

    errors << 'conditional fields must reference an existing field'
  end

  def conditional_field_references
    @conditional_field_references ||= []
  end

  def validate_crm_destination
    destination = @schema['crm_destination']
    if destination.blank?
      errors << 'commercial forms require a CRM destination' if @require_crm_destination
      return
    end

    destination = destination.to_h
    valid_ids = %w[kanban_board_id kanban_stage_id inbox_id].all? do |key|
      destination[key].to_i.positive?
    end
    valid_policy = OPPORTUNITY_POLICIES.include?(destination['opportunity_policy'])
    return if valid_ids && valid_policy

    errors << 'CRM destination must define a valid board, stage, inbox, and opportunity policy'
  end

  def validate_opportunity_mapping(field_keys)
    mapping = @schema.dig('crm_mapping', 'kanban_card', 'custom_field_values')
    return if mapping.blank?

    entries_are_valid = mapping.is_a?(Hash) && mapping.all? do |field_key, answer_key|
      field_key.to_s.match?(KEY_PATTERN) && field_keys.include?(answer_key.to_s)
    end
    errors << 'opportunity mapping must reference published fields' unless entries_are_valid
    errors << 'opportunity mapping requires a CRM destination' if @schema['crm_destination'].blank?
  end

  def validate_public_contact_mapping(field_keys)
    return unless @require_public_contact_mapping

    contact_mapping = @schema.dig('crm_mapping', 'contact').to_h
    mapped_name = contact_mapping['name'].to_s
    mapped_email = contact_mapping['email'].to_s
    mapped_phone = contact_mapping['phone_number'].to_s
    has_name = field_keys.include?(mapped_name)
    has_contact_method = field_keys.include?(mapped_email) || field_keys.include?(mapped_phone)
    return if has_name && has_contact_method

    errors << 'public forms require contact mapping for name and email or phone'
  end
end
