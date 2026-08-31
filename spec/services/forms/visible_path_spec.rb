require 'rails_helper'

RSpec.describe Forms::VisiblePath do
  # Anamnese real: se está grávida, encaminha; se nunca fez procedimento,
  # salta a pergunta sobre quais foram.
  def schema(logics: [])
    {
      'sections' => [
        {
          'key' => 'saude',
          'fields' => [
            { 'key' => 'nome', 'type' => 'text', 'label' => 'Nome' },
            { 'key' => 'gravida', 'type' => 'select', 'label' => 'Grávida?', 'options' => %w[Sim Não] },
            { 'key' => 'ja_fez', 'type' => 'select', 'label' => 'Já fez procedimento?', 'options' => %w[Sim Não] },
            { 'key' => 'quais', 'type' => 'textarea', 'label' => 'Quais?' },
            { 'key' => 'alergias', 'type' => 'textarea', 'label' => 'Alergias' }
          ]
        }
      ],
      'endings' => [{ 'key' => 'encaminhar', 'label' => 'Vamos falar consigo' }],
      'logics' => logics
    }
  end

  def regra(owner:, ref:, comparison:, expected:, target:)
    { 'field_key' => owner,
      'payloads' => [{ 'condition' => { 'ref' => ref, 'comparison' => comparison, 'expected' => expected },
                       'action' => { 'kind' => 'navigate', 'field_key' => target } }] }
  end

  it 'walks every question when there is no logic' do
    percurso = described_class.new(schema: schema, answers: {})

    expect(percurso.keys).to eq(%w[nome gravida ja_fez quais alergias])
  end

  it 'skips what the jump leaves behind' do
    logics = [regra(owner: 'ja_fez', ref: 'ja_fez', comparison: 'is', expected: 'Não', target: 'alergias')]
    percurso = described_class.new(schema: schema(logics: logics), answers: { 'ja_fez' => 'Não' })

    # `quais` não foi escondida por uma condição sua: ficou pelo caminho.
    expect(percurso.keys).to eq(%w[nome gravida ja_fez alergias])
    expect(percurso).not_to be_visible('quais')
  end

  it 'walks straight through when the condition does not hold' do
    logics = [regra(owner: 'ja_fez', ref: 'ja_fez', comparison: 'is', expected: 'Não', target: 'alergias')]
    percurso = described_class.new(schema: schema(logics: logics), answers: { 'ja_fez' => 'Sim' })

    expect(percurso.keys).to eq(%w[nome gravida ja_fez quais alergias])
  end

  it 'ends the form when the jump points at an ending' do
    logics = [regra(owner: 'gravida', ref: 'gravida', comparison: 'is', expected: 'Sim', target: 'encaminhar')]
    percurso = described_class.new(schema: schema(logics: logics), answers: { 'gravida' => 'Sim' })

    expect(percurso.keys).to eq(%w[nome gravida])
  end

  it 'uses the first rule that holds, and ignores the ones after it' do
    logics = [{ 'field_key' => 'ja_fez',
                'payloads' => [
                  { 'condition' => { 'ref' => 'ja_fez', 'comparison' => 'is_not_empty', 'expected' => nil },
                    'action' => { 'kind' => 'navigate', 'field_key' => 'alergias' } },
                  { 'condition' => { 'ref' => 'ja_fez', 'comparison' => 'is', 'expected' => 'Sim' },
                    'action' => { 'kind' => 'navigate', 'field_key' => 'quais' } }
                ] }]
    percurso = described_class.new(schema: schema(logics: logics), answers: { 'ja_fez' => 'Sim' })

    expect(percurso.keys).to eq(%w[nome gravida ja_fez alergias])
  end

  it 'refuses to jump backwards instead of looping forever' do
    logics = [regra(owner: 'quais', ref: 'quais', comparison: 'is_not_empty', expected: nil, target: 'nome')]
    percurso = described_class.new(schema: schema(logics: logics), answers: { 'quais' => 'toxina' })

    expect(percurso.keys).to eq(%w[nome gravida ja_fez quais alergias])
  end

  it 'ignores a calculation when deciding the path' do
    logics = [{ 'field_key' => 'ja_fez',
                'payloads' => [{ 'condition' => { 'ref' => 'ja_fez', 'comparison' => 'is', 'expected' => 'Sim' },
                                 'action' => { 'kind' => 'calculate', 'variable' => 'risco',
                                               'operator' => 'addition', 'value' => '2' } }] }]
    percurso = described_class.new(schema: schema(logics: logics), answers: { 'ja_fez' => 'Sim' })

    # Calcular não muda o caminho; só somar a uma variável oculta.
    expect(percurso.keys).to eq(%w[nome gravida ja_fez quais alergias])
  end

  describe 'versões já publicadas' do
    it 'still honours the old visible_when' do
      antigo = {
        'sections' => [{ 'key' => 's', 'fields' => [
          { 'key' => 'ja_fez', 'type' => 'select', 'label' => 'Já fez?', 'options' => %w[Sim Não] },
          { 'key' => 'quais', 'type' => 'textarea', 'label' => 'Quais?',
            'visible_when' => { 'field' => 'ja_fez', 'operator' => 'equals', 'value' => 'Sim' } }
        ] }]
      }

      # As versões são imutáveis e continuam a receber respostas: partir isto
      # esconderia perguntas de formulários que já estão no ar.
      expect(described_class.new(schema: antigo, answers: { 'ja_fez' => 'Sim' }).keys).to eq(%w[ja_fez quais])
      expect(described_class.new(schema: antigo, answers: { 'ja_fez' => 'Não' }).keys).to eq(%w[ja_fez])
    end
  end
end
