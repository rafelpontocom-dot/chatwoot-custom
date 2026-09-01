class Forms::AnswersValidator
  attr_reader :errors

  def initialize(schema:, answers:)
    @schema = schema.to_h
    # O formulário público envia `multipart/form-data` e o `FormData` do
    # navegador converte tudo em texto: o `true` de um consentimento chega
    # como `"true"`. Sem isto, nenhum consentimento obrigatório passava.
    @answers = Forms::AnswerCoercion.call(@schema, answers.to_h.stringify_keys)
    @errors = []
  end

  def valid?
    return errors.empty? if @validated

    @validated = true
    answer_fields.each { |field| validate_field(field) }
    errors.empty?
  end

  def permitted_answers
    valid?
    answer_fields.each_with_object({}) do |field, result|
      key = field.fetch('key')
      result[key] = @answers[key] if @answers.key?(key)
    end
  end

  private

  def fields
    @schema.fetch('sections', []).flat_map { |section| section.fetch('fields', []) }
  end

  def visible_path
    @visible_path ||= Forms::VisiblePath.new(schema: @schema, answers: @answers)
  end

  def visible_fields
    fields.select { |field| field['type'] != 'hidden' && visible_path.visible?(field['key']) }
  end

  def answer_fields
    visible_fields.reject { |field| field['type'] == 'attachment' }
  end

  def validate_field(field)
    key = field.fetch('key')
    value = @answers[key]
    # Consentimento primeiro: por aceitar ele vale `false`, que o Rails
    # considera vazio — e a pessoa levaria «não pode ficar em branco» quando o
    # que precisa de ler é que tem de aceitar.
    return validate_consent(field, value) if field['type'] == 'consent'
    return validate_required(field, value) if blank_value?(value)

    validate_selection(field, value) if Forms::SchemaValidator::SELECTION_TYPES.include?(field['type'])
    validate_email(field, value) if field['type'] == 'email'
    validate_typed_value(field, value)
  end

  def validate_required(field, value)
    return unless field['required']

    errors << "#{field['label']} não pode ficar em branco" if blank_value?(value)
  end

  def validate_selection(field, value)
    allowed_values = field.fetch('options').map { |option| option.is_a?(Hash) ? option['value'] : option }
    selected_values = field['type'] == 'multi_select' ? Array(value) : [value]
    errors << "#{field['label']} possui uma opção inválida" unless selected_values.all? { |selected| allowed_values.include?(selected) }
  end

  # Obrigatório só passa aceite. Um opcional pode ficar por aceitar — recusar
  # uma newsletter é uma resposta, não uma falha de preenchimento —, mas o que
  # a coerção não reconheceu como booleano não é consentimento nenhum.
  def validate_consent(field, value)
    return errors << "#{field['label']} precisa ser aceito" if field['required'] && value != true
    return if value == true || blank_value?(value)

    errors << "#{field['label']} precisa ser aceito ou recusado"
  end

  def validate_email(field, value)
    errors << "#{field['label']} possui um formato inválido" unless value.match?(URI::MailTo::EMAIL_REGEXP)
  end

  def validate_typed_value(field, value)
    case field['type']
    when 'number', 'currency'
      validate_number(field, value)
    when 'date'
      validate_date(field, value)
    when 'datetime'
      validate_datetime(field, value)
    end
  end

  def validate_number(field, value)
    number = Float(value)
    return if number.finite?

    errors << "#{field['label']} precisa ser um número válido"
  rescue ArgumentError, TypeError
    errors << "#{field['label']} precisa ser um número válido"
  end

  def validate_date(field, value)
    Date.iso8601(value.to_s)
  rescue ArgumentError
    errors << "#{field['label']} precisa ser uma data válida"
  end

  def validate_datetime(field, value)
    DateTime.iso8601(value.to_s)
  rescue ArgumentError
    errors << "#{field['label']} precisa ser uma data e hora válida"
  end

  def blank_value?(value)
    value.blank? || (value.is_a?(Array) && value.empty?)
  end
end
