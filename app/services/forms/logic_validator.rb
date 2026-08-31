# Recusa publicar uma lógica que o renderizador não conseguiria cumprir.
#
# Vive separado do `SchemaValidator` porque as perguntas que faz são de outra
# natureza: aquele trata de estrutura — secções, chaves, tipos —, este trata de
# referências entre perguntas, de operadores que cabem no tipo, e de saltos que
# não prendem o paciente num ciclo.
class Forms::LogicValidator
  KEY_PATTERN = /\A[a-z][a-z0-9_]*\z/

  attr_reader :errors

  def initialize(schema:, field_keys:, field_types:)
    @schema = schema.to_h
    @field_keys = field_keys
    @field_types = field_types
    @errors = []
    validate
  end

  private

  attr_reader :field_keys, :field_types

  def validate
    validate_variables
    validate_hidden_fields
    validate_logics
  end

  def variable_names
    @variable_names ||= Array(@schema['variables']).filter_map { |variable| variable.to_h['name'].to_s.presence }
  end

  def ending_keys
    @ending_keys ||= Array(@schema['endings']).filter_map { |ending| ending.to_h['key'].to_s.presence }
  end

  def validate_variables
    variables = @schema['variables']
    return if variables.blank?
    return errors << 'variables must be a list' unless variables.is_a?(Array)

    seen = []
    variables.each do |variable|
      validate_variable(variable.to_h, seen)
    end
  end

  def validate_variable(variable, seen)
    name = variable['name'].to_s
    errors << 'variables must define a key-safe name' unless name.match?(KEY_PATTERN)
    errors << 'variable names must be unique' if seen.include?(name)
    errors << 'variables must declare a supported kind' unless Forms::Logic::VARIABLE_KINDS.include?(variable['kind'].to_s)
    seen << name
  end

  # Campos ocultos são preenchidos pelo servidor a partir do convite. Uma chave
  # repetida com uma pergunta deixaria a resposta do paciente sobrescrever o
  # que nós lá pusemos.
  def validate_hidden_fields
    hidden = @schema['hidden_fields']
    return if hidden.blank?
    return errors << 'hidden fields must be a list' unless hidden.is_a?(Array)

    hidden.each do |entry|
      key = (entry.is_a?(Hash) ? entry.to_h['key'] : entry).to_s
      errors << 'hidden fields must define a key-safe name' unless key.match?(KEY_PATTERN)
      errors << 'hidden field keys must not collide with question keys' if field_keys.include?(key)
    end
  end

  def validate_logics
    logics = @schema['logics']
    return if logics.blank?
    return errors << 'logics must be a list' unless logics.is_a?(Array)

    logics.each { |logic| validate_logic(logic.to_h) }
  end

  def validate_logic(logic)
    owner = logic['field_key'].to_s
    errors << 'logic must reference an existing field' unless field_keys.include?(owner)

    payloads = logic['payloads']
    return errors << 'logic must define payloads' unless payloads.is_a?(Array) && payloads.present?

    payloads.each { |payload| validate_payload(payload.to_h, owner) }
  end

  def validate_payload(payload, owner)
    validate_condition(payload['condition'].to_h)
    validate_action(payload['action'].to_h, owner)
  end

  def validate_condition(condition)
    ref = condition['ref'].to_s
    return errors << 'logic conditions must reference an existing field' unless field_keys.include?(ref)

    return if Forms::Logic.supports?(field_types[ref], condition['comparison'].to_s)

    errors << 'logic comparison is not supported by the referenced field type'
  end

  def validate_action(action, owner)
    kind = action['kind'].to_s
    return errors << 'logic actions must declare a supported kind' unless Forms::Logic::ACTIONS.include?(kind)

    kind == 'navigate' ? validate_navigate(action, owner) : validate_calculate(action)
  end

  def validate_navigate(action, owner)
    target = action['field_key'].to_s
    # Saltar para si própria prende o respondente na mesma pergunta para sempre.
    return errors << 'logic cannot navigate to its own field' if target == owner
    return if field_keys.include?(target) || ending_keys.include?(target)

    errors << 'logic must navigate to an existing field or ending'
  end

  def validate_calculate(action)
    errors << 'logic must calculate an existing variable' unless variable_names.include?(action['variable'].to_s)
    return if Forms::Logic::CALCULATE_OPERATORS.include?(action['operator'].to_s)

    errors << 'logic must use a supported calculate operator'
  end
end
