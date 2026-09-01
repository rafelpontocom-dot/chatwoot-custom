# Devolve a booleanos o que o formulário público não consegue enviar como tal.
#
# A página pública envia `multipart/form-data`, e o `FormData` do navegador
# converte tudo em texto: o `true` de um consentimento chega ao servidor como
# a string `"true"`. A validação comparava com o booleano e recusava sempre —
# nenhum paciente conseguia submeter um formulário com consentimento obrigatório.
#
# Corrigir no cliente não resolveria: o `FormData` não transporta booleanos, e
# um JSON no corpo mudaria a forma como os anexos são enviados. A fronteira é
# aqui, onde o texto do formulário passa a ser dado.
module Forms::AnswerCoercion
  BOOLEAN_TYPES = %w[consent checkbox].freeze
  VERDADEIROS = %w[true 1 on yes sim].freeze
  FALSOS = %w[false 0 off no não nao].freeze

  module_function

  # Normaliza as respostas contra o schema. O que não for booleano fica intacto:
  # coagir texto livre seria adivinhar o que o paciente escreveu.
  def call(schema, answers)
    tipos = boolean_keys(schema)
    answers.to_h.each_with_object({}) do |(chave, valor), resultado|
      resultado[chave] = tipos.include?(chave.to_s) ? boolean(valor) : valor
    end
  end

  def boolean_keys(schema)
    schema.to_h.fetch('sections', []).flat_map do |section|
      section.to_h.fetch('fields', [])
             .select { |field| BOOLEAN_TYPES.include?(field.to_h['type']) }
             .map { |field| field.to_h['key'].to_s }
    end
  end

  # Um valor já booleano passa; texto reconhecido converte; o resto fica como
  # está, para o validador poder recusar e dizer porquê.
  def boolean(valor)
    return valor if [true, false].include?(valor)

    normalizado = valor.to_s.strip.downcase
    return true if VERDADEIROS.include?(normalizado)
    return false if FALSOS.include?(normalizado)

    valor
  end
end
