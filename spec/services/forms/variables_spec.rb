require 'rails_helper'

RSpec.describe Forms::Variables do
  def schema(logics, variables: [{ 'name' => 'score', 'kind' => 'number', 'initial' => '0' }])
    {
      'sections' => [{
        'key' => 's',
        'fields' => [
          { 'key' => 'dor', 'type' => 'select', 'label' => 'Dor', 'options' => %w[sim nao] },
          { 'key' => 'febre', 'type' => 'select', 'label' => 'Febre', 'options' => %w[sim nao] }
        ]
      }],
      'variables' => variables,
      'logics' => logics
    }
  end

  def calcula(field_key, expected, operator, value)
    {
      'field_key' => field_key,
      'payloads' => [{
        'condition' => { 'ref' => field_key, 'comparison' => 'is', 'expected' => expected },
        'action' => { 'kind' => 'calculate', 'variable' => 'score', 'operator' => operator, 'value' => value }
      }]
    }
  end

  it 'starts from the declared initial value' do
    variables = [{ 'name' => 'score', 'kind' => 'number', 'initial' => '10' }]

    expect(described_class.new(schema: schema([], variables: variables), answers: {}).call).to eq('score' => 10.0)
  end

  it 'adds up every rule that holds along the path' do
    logics = [calcula('dor', 'sim', 'addition', '3'), calcula('febre', 'sim', 'addition', '5')]

    resultado = described_class.new(schema: schema(logics), answers: { 'dor' => 'sim', 'febre' => 'sim' }).call

    expect(resultado).to eq('score' => 8.0)
  end

  it 'leaves the score untouched when the condition does not hold' do
    logics = [calcula('dor', 'sim', 'addition', '3')]

    resultado = described_class.new(schema: schema(logics), answers: { 'dor' => 'nao' }).call

    expect(resultado).to eq('score' => 0.0)
  end

  it 'never divides by zero in the middle of a submission' do
    logics = [calcula('dor', 'sim', 'addition', '8'), calcula('febre', 'sim', 'division', '0')]

    resultado = described_class.new(schema: schema(logics), answers: { 'dor' => 'sim', 'febre' => 'sim' }).call

    expect(resultado).to eq('score' => 8.0)
  end

  it 'ignores a rule on a question the respondent never reached' do
    # `febre` fica para trás por um salto: somar por ela contaria uma resposta
    # que ninguém deu.
    logics = [
      {
        'field_key' => 'dor',
        'payloads' => [{
          'condition' => { 'ref' => 'dor', 'comparison' => 'is', 'expected' => 'nao' },
          'action' => { 'kind' => 'navigate', 'field_key' => 'fim' }
        }]
      },
      calcula('febre', 'sim', 'addition', '5')
    ]

    resultado = described_class.new(schema: schema(logics), answers: { 'dor' => 'nao', 'febre' => 'sim' }).call

    expect(resultado).to eq('score' => 0.0)
  end

  it 'only assigns to a text variable, and never does arithmetic on it' do
    variables = [{ 'name' => 'origem', 'kind' => 'text', 'initial' => 'desconhecida' }]
    logics = [{
      'field_key' => 'dor',
      'payloads' => [{
        'condition' => { 'ref' => 'dor', 'comparison' => 'is', 'expected' => 'sim' },
        'action' => { 'kind' => 'calculate', 'variable' => 'origem', 'operator' => 'assignment', 'value' => 'triagem' }
      }]
    }]

    resultado = described_class.new(schema: schema(logics, variables: variables), answers: { 'dor' => 'sim' }).call

    expect(resultado).to eq('origem' => 'triagem')
  end
end
