require 'rails_helper'

RSpec.describe Forms::AnswerCoercion do
  let(:schema) do
    {
      'sections' => [{
        'key' => 's',
        'fields' => [
          { 'key' => 'declaracao', 'type' => 'consent', 'label' => 'Declaro', 'required' => true },
          { 'key' => 'aceita', 'type' => 'checkbox', 'label' => 'Aceita' },
          { 'key' => 'nome', 'type' => 'text', 'label' => 'Nome' },
          { 'key' => 'peso', 'type' => 'number', 'label' => 'Peso' }
        ]
      }]
    }
  end

  it 'turns the text a browser form sends back into a boolean' do
    # `FormData` converte tudo em texto: o `true` de um consentimento chega
    # ao servidor como `"true"`, e a validação comparava com o booleano.
    resultado = described_class.call(schema, 'declaracao' => 'true', 'aceita' => 'false')

    expect(resultado['declaracao']).to be(true)
    expect(resultado['aceita']).to be(false)
  end

  it 'accepts the shapes a checkbox can arrive in' do
    %w[true 1 on yes sim].each do |verdadeiro|
      expect(described_class.call(schema, 'declaracao' => verdadeiro)['declaracao']).to be(true)
    end
    %w[false 0 off no não].each do |falso|
      expect(described_class.call(schema, 'declaracao' => falso)['declaracao']).to be(false)
    end
  end

  it 'leaves a real boolean alone' do
    resultado = described_class.call(schema, 'declaracao' => true, 'aceita' => false)

    expect(resultado['declaracao']).to be(true)
    expect(resultado['aceita']).to be(false)
  end

  it 'never touches an answer that is not a boolean field' do
    # Coagir texto livre seria adivinhar o que o paciente escreveu: alguém que
    # responda «sim» a uma pergunta aberta não quer um booleano no lugar.
    resultado = described_class.call(schema, 'nome' => 'sim', 'peso' => '82')

    expect(resultado['nome']).to eq('sim')
    expect(resultado['peso']).to eq('82')
  end

  it 'leaves an unrecognised value for the validator to refuse' do
    expect(described_class.call(schema, 'declaracao' => 'talvez')['declaracao']).to eq('talvez')
  end
end
