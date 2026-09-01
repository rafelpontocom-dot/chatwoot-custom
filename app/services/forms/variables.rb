# O que as regras de cálculo somaram, no fim do percurso.
#
# `calculate` era validado na publicação e editável no painel, e não corria em
# lado nenhum: a secretária montava «Então calcular», publicava, e o valor
# nunca existia. Prometer e não cumprir é pior do que não oferecer.
#
# Deriva na leitura em vez de guardar. O schema da versão é imutável e as
# respostas estão gravadas, portanto o resultado é sempre o mesmo — e um valor
# derivado não pode divergir daquilo que o originou, nem obriga a decidir onde
# guardar um número calculado a partir de resposta clínica.
class Forms::Variables
  def initialize(schema:, answers:)
    @schema = schema.to_h
    @answers = answers.to_h.stringify_keys
  end

  def call
    valores = initial_values
    apply_rules(valores)
    valores
  end

  private

  def definitions
    @definitions ||= Array(@schema['variables']).map(&:to_h).select { |variable| variable['name'].to_s.present? }
  end

  def initial_values
    definitions.to_h do |variable|
      inicial = variable['initial']
      [variable['name'].to_s, variable['kind'].to_s == 'text' ? inicial.to_s : to_number(inicial).to_f]
    end
  end

  def kinds
    @kinds ||= definitions.to_h { |variable| [variable['name'].to_s, variable['kind'].to_s] }
  end

  def logics_by_field
    @logics_by_field ||= Array(@schema['logics']).index_by { |logic| logic.to_h['field_key'].to_s }
  end

  # Pela ordem em que o respondente passou pelas perguntas: o valor de uma
  # variável depende de que regras correram antes dela.
  def apply_rules(valores)
    percurso = Forms::VisiblePath.new(schema: @schema, answers: @answers).keys
    percurso.each do |key|
      action = matched_action(key)
      next unless action['kind'].to_s == 'calculate'

      apply(valores, action)
    end
  end

  # A mesma primeira-regra-que-vale do percurso: uma pergunta aplica uma ação,
  # não todas as que se cumprem.
  def matched_action(key)
    payloads = Array(logics_by_field[key].to_h['payloads'])
    matched = payloads.find { |payload| Forms::Logic.satisfied?(payload.to_h['condition'].to_h, @answers) }
    matched.to_h['action'].to_h
  end

  def apply(valores, action)
    name = action['variable'].to_s
    return unless valores.key?(name)

    valores[name] = if kinds[name] == 'text'
                      apply_text(valores[name], action)
                    else
                      apply_number(valores[name], action)
                    end
  end

  # Texto só recebe. Somar textos parece útil e não é: ninguém consegue prever
  # o que sai de multiplicar uma resposta aberta.
  def apply_text(current, action)
    action['operator'].to_s == 'assignment' ? action['value'].to_s : current
  end

  # Tabela de despacho, como em `Forms::Logic`: acrescentar um operador passa a
  # ser acrescentar uma linha.
  ARITHMETIC = {
    'assignment' => ->(_current, operand) { operand },
    'addition' => ->(current, operand) { current + operand },
    'subtraction' => ->(current, operand) { current - operand },
    'multiplication' => ->(current, operand) { current * operand },
    # Dividir por zero devolveria infinito e isto corre no meio de uma submissão
    # de paciente: o valor fica como estava.
    'division' => ->(current, operand) { operand.zero? ? current : current / operand }
  }.freeze

  def apply_number(current, action)
    operand = to_number(action['value'])
    operacao = ARITHMETIC[action['operator'].to_s]
    return current if operand.nil? || operacao.nil?

    operacao.call(current, operand)
  end

  def to_number(value)
    Float(value.to_s.tr(',', '.'), exception: false)
  end
end
