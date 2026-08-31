# Que perguntas o respondente viu, de facto.
#
# Esconder e saltar não são a mesma coisa, e é por isso que isto é um percurso
# e não um predicado por campo. `visible_when` respondia «este campo aparece?»
# olhando só para ele. Uma regra de salto responde «depois desta, qual é a
# próxima?» — e tudo o que fica pelo caminho não foi visto, mesmo que nenhuma
# condição o mencione.
#
# Corre nos dois lados: a interface usa-o para conduzir o preenchimento, e o
# servidor volta a corrê-lo no envio para não persistir resposta de pergunta
# que ninguém chegou a ver.
class Forms::VisiblePath
  def initialize(schema:, answers:)
    @schema = schema.to_h
    @answers = answers.to_h.stringify_keys
  end

  # As chaves efetivamente percorridas, em ordem.
  def keys
    @keys ||= walk
  end

  def visible?(key)
    keys.include?(key.to_s)
  end

  private

  def fields
    @fields ||= @schema.fetch('sections', []).flat_map { |section| section.to_h.fetch('fields', []) }
  end

  def ordered_keys
    @ordered_keys ||= fields.map { |field| field.to_h['key'].to_s }
  end

  def field_by_key
    @field_by_key ||= fields.index_by { |field| field.to_h['key'].to_s }
  end

  def logics_by_field
    @logics_by_field ||= Array(@schema['logics']).index_by { |logic| logic.to_h['field_key'].to_s }
  end

  def walk
    visited = []
    index = 0
    # Um formulário não pode ter mais passos do que perguntas: se contar mais,
    # há um ciclo e paramos em vez de prender o pedido.
    limite = ordered_keys.size + 1

    while index < ordered_keys.size && visited.size < limite
      key = ordered_keys[index]
      index = advance(key, index, visited)
      break if index.nil?
    end

    visited
  end

  # Devolve o próximo índice, ou `nil` quando a regra manda para um final.
  def advance(key, index, visited)
    return index + 1 unless legacy_visible?(field_by_key[key])

    visited << key
    target = navigate_target(key)
    return index + 1 if target.blank?
    return nil unless ordered_keys.include?(target)

    destino = ordered_keys.index(target)
    # Só para a frente. Saltar para trás repetiria perguntas já respondidas e,
    # com duas regras a apontar uma para a outra, nunca terminaria.
    destino > index ? destino : index + 1
  end

  # Compatibilidade com versões já publicadas, que são imutáveis: elas trazem
  # `visible_when` e continuam a ser respondidas por pacientes.
  def legacy_visible?(field)
    condition = field.to_h['visible_when'].to_h
    return true if condition.blank?

    Forms::Logic.matches?(condition['operator'], @answers[condition['field'].to_s], condition['value'])
  end

  def navigate_target(key)
    payloads = logics_by_field[key].to_h['payloads']
    return nil if payloads.blank?

    # A primeira regra que se cumpre é a que vale; as seguintes não correm.
    matched = Array(payloads).find { |payload| condition_matches?(payload.to_h['condition'].to_h) }
    action = matched.to_h['action'].to_h
    action['kind'].to_s == 'navigate' ? action['field_key'].to_s : nil
  end

  def condition_matches?(condition)
    return false if condition.blank?

    Forms::Logic.satisfied?(condition, @answers)
  end
end
