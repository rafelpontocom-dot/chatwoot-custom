# Definição única da lógica de formulário.
#
# O modelo antigo tinha um operador — `equals` — numa condição por campo, e só
# escondia o campo. Aqui ele passa a ter operadores por tipo de pergunta, ações
# de salto e de cálculo, e regras avaliadas em ordem.
#
# Esta é a fonte de verdade para os dois lados: o `SchemaValidator` recusa
# publicar o que não estiver aqui, e o `AnswersValidator` reavalia no envio a
# mesma lógica que a interface usou. Enquanto a tabela viver em dois sítios,
# ela diverge — foi o que aconteceu com as classes de campo do design system.
module Forms::Logic
  # Servem a qualquer tipo: perguntar se foi respondida não depende do formato.
  COMMON_OPERATORS = %w[is_empty is_not_empty].freeze

  TEXT_OPERATORS = %w[is is_not contains does_not_contain starts_with ends_with].freeze
  SINGLE_CHOICE_OPERATORS = %w[is is_not].freeze
  MULTIPLE_CHOICE_OPERATORS = %w[is is_not contains does_not_contain].freeze
  NUMBER_OPERATORS = %w[equal not_equal greater_than greater_or_equal_than less_or_equal_than].freeze
  DATE_OPERATORS = %w[is is_not is_before is_after].freeze

  OPERATORS_BY_TYPE = {
    'text' => TEXT_OPERATORS,
    'textarea' => TEXT_OPERATORS,
    'email' => TEXT_OPERATORS,
    'phone' => TEXT_OPERATORS,
    'number' => NUMBER_OPERATORS,
    'currency' => NUMBER_OPERATORS,
    'date' => DATE_OPERATORS,
    'datetime' => DATE_OPERATORS,
    'select' => SINGLE_CHOICE_OPERATORS,
    'checkbox' => SINGLE_CHOICE_OPERATORS,
    'consent' => SINGLE_CHOICE_OPERATORS,
    'multi_select' => MULTIPLE_CHOICE_OPERATORS
  }.freeze

  ACTIONS = %w[navigate calculate].freeze
  CALCULATE_OPERATORS = %w[addition subtraction multiplication division assignment].freeze
  # Um nível só, sem parênteses: é o que mantém a regra legível por quem a escreve.
  COMBINATORS = %w[all any].freeze
  VARIABLE_KINDS = %w[number text].freeze

  module_function

  # Assinatura, anexo e campo oculto caem só nos comuns: não há "contém" útil
  # numa assinatura.
  def operators_for(field_type)
    OPERATORS_BY_TYPE.fetch(field_type.to_s, []) + COMMON_OPERATORS
  end

  def supports?(field_type, comparison)
    operators_for(field_type).include?(comparison.to_s)
  end

  # Tabela de despacho em vez de um `case` de catorze ramos: acrescentar um
  # operador passa a ser acrescentar uma linha, e o validador e o avaliador
  # continuam a ler a mesma lista.
  COMPARATORS = {
    'is_empty' => ->(answer, _expected) { blank_answer?(answer) },
    'is_not_empty' => ->(answer, _expected) { !blank_answer?(answer) },
    'is' => ->(answer, expected) { equal?(answer, expected) },
    'equal' => ->(answer, expected) { equal?(answer, expected) },
    # `equals` é o operador do modelo antigo. Não aparece em `operators_for`,
    # por isso não pode entrar num schema novo — mas as versões publicadas são
    # imutáveis e ainda o trazem, e continuam a ser respondidas por pacientes.
    'equals' => ->(answer, expected) { equal?(answer, expected) },
    'is_not' => ->(answer, expected) { !equal?(answer, expected) },
    'not_equal' => ->(answer, expected) { !equal?(answer, expected) },
    'contains' => ->(answer, expected) { contains?(answer, expected) },
    'does_not_contain' => ->(answer, expected) { !contains?(answer, expected) },
    'starts_with' => ->(answer, expected) { text(answer).start_with?(text(expected)) },
    'ends_with' => ->(answer, expected) { text(answer).end_with?(text(expected)) },
    'greater_than' => ->(answer, expected) { compare_numbers(answer, expected) { |a, b| a > b } },
    'greater_or_equal_than' => ->(answer, expected) { compare_numbers(answer, expected) { |a, b| a >= b } },
    'less_or_equal_than' => ->(answer, expected) { compare_numbers(answer, expected) { |a, b| a <= b } },
    'is_before' => ->(answer, expected) { compare_dates(answer, expected) { |a, b| a < b } },
    'is_after' => ->(answer, expected) { compare_dates(answer, expected) { |a, b| a > b } }
  }.freeze

  # Avalia uma condição contra a resposta dada. Uma comparação que não se
  # aplica ao valor recebido devolve `false` — nunca levanta, porque isto corre
  # no meio de uma submissão de paciente.
  def matches?(comparison, answer, expected)
    comparator = COMPARATORS[comparison.to_s]
    return false if comparator.nil?

    instance_exec(answer, expected, &comparator)
  end

  def blank_answer?(answer)
    answer.blank? || (answer.is_a?(Array) && answer.compact_blank.empty?)
  end

  # Seleção múltipla responde com lista: «é» significa exatamente aquele
  # conjunto, e «contém» significa que a opção está entre as escolhidas.
  def equal?(answer, expected)
    return Array(answer).map { |item| text(item) }.sort == Array(expected).map { |item| text(item) }.sort if answer.is_a?(Array)

    text(answer) == text(expected)
  end

  def contains?(answer, expected)
    return Array(answer).any? { |item| text(item) == text(expected) } if answer.is_a?(Array)

    text(answer).include?(text(expected))
  end

  def text(value)
    value.to_s.strip
  end

  def compare_numbers(answer, expected)
    left = Float(answer.to_s.tr(',', '.'), exception: false)
    right = Float(expected.to_s.tr(',', '.'), exception: false)
    return false if left.nil? || right.nil?

    yield(left, right)
  end

  def compare_dates(answer, expected)
    left = parse_time(answer)
    right = parse_time(expected)
    return false if left.nil? || right.nil?

    yield(left, right)
  end

  def parse_time(value)
    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
