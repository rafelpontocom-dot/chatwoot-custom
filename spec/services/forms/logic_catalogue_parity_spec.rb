require 'rails_helper'

# A tabela de operadores vive em dois sítios por necessidade: a interface tem de
# oferecer os operadores sem ir ao servidor a cada seleção, e o servidor tem de
# recusar o que não conhece. Duas cópias divergem sozinhas — este teste é o que
# impede isso, lendo o ficheiro do front e comparando com o Ruby.
RSpec.describe Forms::Logic do
  let(:catalogue) do
    Rails.root.join('app/javascript/dashboard/routes/dashboard/forms/logicCatalogue.js').read
  end

  # Lê `const NOME = ['a', 'b'];` ou uma entrada de objeto `chave: [...]`.
  def js_list(source, name)
    match = source.match(/#{Regexp.escape(name)}\s*[=:]\s*\[(.*?)\]/m)
    raise "não encontrei #{name} no catálogo do front" if match.nil?

    match[1].scan(/'([a-z_]+)'/).flatten
  end

  def js_type_operators(source, type)
    body = source.match(/OPERATORS_BY_TYPE\s*=\s*\{(.*?)\n\};/m)[1]
    constant = body.match(/^\s*#{Regexp.escape(type)}:\s*(\w+),/)[1]
    js_list(source, "const #{constant}")
  end

  it 'offers the same operators for every field type the server knows' do
    Forms::Logic::OPERATORS_BY_TYPE.each_key do |type|
      expect(js_type_operators(catalogue, type)).to eq(Forms::Logic::OPERATORS_BY_TYPE[type]),
                                                    "operadores de `#{type}` divergem entre o Ruby e o catálogo do front"
    end
  end

  it 'knows exactly the same field types' do
    body = catalogue.match(/OPERATORS_BY_TYPE\s*=\s*\{(.*?)\n\};/m)[1]
    front_types = body.scan(/^\s*(\w+):/).flatten

    expect(front_types).to match_array(Forms::Logic::OPERATORS_BY_TYPE.keys)
  end

  it 'shares the common operators, the actions and the arithmetic' do
    expect(js_list(catalogue, 'const COMMON_OPERATORS')).to eq(Forms::Logic::COMMON_OPERATORS)
    expect(js_list(catalogue, 'const ACTIONS')).to eq(Forms::Logic::ACTIONS)
    expect(js_list(catalogue, 'const CALCULATE_OPERATORS')).to eq(Forms::Logic::CALCULATE_OPERATORS)
    expect(js_list(catalogue, 'const VARIABLE_KINDS')).to eq(Forms::Logic::VARIABLE_KINDS)
    expect(js_list(catalogue, 'const COMBINATORS')).to eq(Forms::Logic::COMBINATORS)
  end

  it 'never offers the legacy operator to a new schema' do
    # `equals` sobrevive só para as versões já publicadas, que são imutáveis.
    # Se aparecesse no catálogo do front, entraria em schema novo.
    expect(catalogue).not_to include("'equals'")
  end
end
