require 'rails_helper'

RSpec.describe Forms::SchemaValidator do
  # A lógica é validada através do SchemaValidator, que é a porta usada por
  # `publish!` — testar por aqui garante que a ligação não se perde.
  def anamnese(logics: [], variables: [], hidden_fields: [], endings: [])
    {
      'sections' => [
        {
          'key' => 'saude',
          'fields' => [
            { 'key' => 'gravida', 'type' => 'select', 'label' => 'Está grávida?', 'options' => %w[Sim Não] },
            { 'key' => 'medicacao', 'type' => 'multi_select', 'label' => 'Medicação contínua',
              'options' => %w[Anticoagulante Nenhuma] },
            { 'key' => 'idade', 'type' => 'number', 'label' => 'Idade' },
            { 'key' => 'assinatura', 'type' => 'signature', 'label' => 'Assinatura' },
            { 'key' => 'observacoes', 'type' => 'textarea', 'label' => 'Observações' }
          ]
        }
      ],
      'variables' => variables,
      'hidden_fields' => hidden_fields,
      'endings' => endings,
      'logics' => logics
    }
  end

  def salto(ref:, comparison:, expected:, target:, owner: 'gravida')
    [{ 'field_key' => owner,
       'payloads' => [{ 'condition' => { 'ref' => ref, 'comparison' => comparison, 'expected' => expected },
                        'action' => { 'kind' => 'navigate', 'field_key' => target } }] }]
  end

  it 'accepts a rule that jumps to another question' do
    validator = described_class.new(
      anamnese(logics: salto(ref: 'gravida', comparison: 'is', expected: 'Sim', target: 'observacoes'))
    )

    expect(validator).to be_valid
  end

  it 'accepts a rule that jumps to an ending' do
    schema = anamnese(
      logics: salto(ref: 'gravida', comparison: 'is', expected: 'Sim', target: 'encaminhar'),
      endings: [{ 'key' => 'encaminhar', 'label' => 'Vamos falar consigo' }]
    )

    expect(described_class.new(schema)).to be_valid
  end

  it 'refuses an operator the field type cannot answer' do
    # «começa com» numa assinatura não tem sentido, e o renderizador não saberia
    # o que fazer com isso.
    validator = described_class.new(
      anamnese(logics: salto(ref: 'assinatura', comparison: 'starts_with', expected: 'a', target: 'observacoes'))
    )

    expect(validator).not_to be_valid
    expect(validator.errors).to include('logic comparison is not supported by the referenced field type')
  end

  it 'refuses "contains" on a single choice but allows it on a multiple choice' do
    single = described_class.new(
      anamnese(logics: salto(ref: 'gravida', comparison: 'contains', expected: 'Sim', target: 'observacoes'))
    )
    multiple = described_class.new(
      anamnese(logics: salto(ref: 'medicacao', comparison: 'contains', expected: 'Anticoagulante', target: 'observacoes'))
    )

    expect(single).not_to be_valid
    expect(multiple).to be_valid
  end

  it 'refuses a condition that points at a question that does not exist' do
    validator = described_class.new(
      anamnese(logics: salto(ref: 'inventada', comparison: 'is', expected: 'Sim', target: 'observacoes'))
    )

    expect(validator).not_to be_valid
    expect(validator.errors).to include('logic conditions must reference an existing field')
  end

  it 'refuses a jump onto the question that owns the rule' do
    validator = described_class.new(
      anamnese(logics: salto(ref: 'gravida', comparison: 'is', expected: 'Sim', target: 'gravida'))
    )

    # Saltar para si própria prenderia o paciente na mesma pergunta para sempre.
    expect(validator).not_to be_valid
    expect(validator.errors).to include('logic cannot navigate to its own field')
  end

  it 'refuses a jump to nowhere' do
    validator = described_class.new(
      anamnese(logics: salto(ref: 'gravida', comparison: 'is', expected: 'Sim', target: 'nao_existe'))
    )

    expect(validator).not_to be_valid
    expect(validator.errors).to include('logic must navigate to an existing field or ending')
  end

  describe 'calculate' do
    def calculo(variable:, operator:)
      [{ 'field_key' => 'medicacao',
         'payloads' => [{ 'condition' => { 'ref' => 'medicacao', 'comparison' => 'contains', 'expected' => 'Anticoagulante' },
                          'action' => { 'kind' => 'calculate', 'variable' => variable, 'operator' => operator, 'value' => '2' } }] }]
    end

    it 'accepts a calculation over a declared variable' do
      schema = anamnese(
        logics: calculo(variable: 'risco', operator: 'addition'),
        variables: [{ 'name' => 'risco', 'kind' => 'number', 'initial' => '0' }]
      )

      expect(described_class.new(schema)).to be_valid
    end

    it 'refuses a calculation over a variable nobody declared' do
      validator = described_class.new(anamnese(logics: calculo(variable: 'fantasma', operator: 'addition')))

      expect(validator).not_to be_valid
      expect(validator.errors).to include('logic must calculate an existing variable')
    end

    it 'refuses an arithmetic operation it does not know' do
      schema = anamnese(
        logics: calculo(variable: 'risco', operator: 'exponentiation'),
        variables: [{ 'name' => 'risco', 'kind' => 'number', 'initial' => '0' }]
      )
      validator = described_class.new(schema)

      expect(validator).not_to be_valid
      expect(validator.errors).to include('logic must use a supported calculate operator')
    end
  end

  describe 'hidden fields and variables' do
    it 'refuses a hidden field that collides with a question key' do
      # O servidor preenche o campo oculto a partir do convite; uma chave
      # repetida deixaria a resposta do paciente sobrescrever o nosso valor.
      validator = described_class.new(anamnese(hidden_fields: [{ 'key' => 'gravida' }]))

      expect(validator).not_to be_valid
      expect(validator.errors).to include('hidden field keys must not collide with question keys')
    end

    it 'accepts the invitation context as hidden fields' do
      validator = described_class.new(
        anamnese(hidden_fields: [{ 'key' => 'token' }, { 'key' => 'contato_id' }])
      )

      expect(validator).to be_valid
    end

    it 'refuses two variables with the same name' do
      schema = anamnese(variables: [
                          { 'name' => 'risco', 'kind' => 'number' },
                          { 'name' => 'risco', 'kind' => 'number' }
                        ])
      validator = described_class.new(schema)

      expect(validator).not_to be_valid
      expect(validator.errors).to include('variable names must be unique')
    end
  end

  describe 'condition groups' do
    def grupo(combinator, *condicoes)
      [{ 'field_key' => 'observacoes',
         'payloads' => [{ 'condition' => { 'combinator' => combinator, 'conditions' => condicoes },
                          'action' => { 'kind' => 'navigate', 'field_key' => 'assinatura' } }] }]
    end

    def cond(ref, comparison, expected)
      { 'ref' => ref, 'comparison' => comparison, 'expected' => expected }
    end

    it 'accepts conditions combined with all or any' do
      %w[all any].each do |combinator|
        schema = anamnese(
          logics: grupo(combinator,
                        cond('gravida', 'is', 'Não'),
                        cond('idade', 'greater_than', '60'))
        )

        expect(described_class.new(schema)).to be_valid
      end
    end

    it 'refuses a combinator it does not know' do
      validator = described_class.new(anamnese(logics: grupo('maybe', cond('gravida', 'is', 'Não'))))

      expect(validator).not_to be_valid
      expect(validator.errors).to include('logic groups must combine with all or any')
    end

    it 'refuses an empty group' do
      validator = described_class.new(anamnese(logics: grupo('all')))

      expect(validator).not_to be_valid
      expect(validator.errors).to include('logic groups must contain conditions')
    end

    it 'refuses a group inside a group' do
      # Aninhar pede parênteses, e uma regra com parênteses deixa de se ler
      # como uma frase — que é como a secretaria a mantém.
      aninhado = { 'combinator' => 'any', 'conditions' => [cond('gravida', 'is', 'Sim')] }
      validator = described_class.new(anamnese(logics: grupo('all', aninhado)))

      expect(validator).not_to be_valid
      expect(validator.errors).to include('logic groups cannot contain another group')
    end

    it 'still checks each operator against its own field type inside a group' do
      validator = described_class.new(
        anamnese(logics: grupo('all', cond('assinatura', 'starts_with', 'a')))
      )

      expect(validator).not_to be_valid
      expect(validator.errors).to include('logic comparison is not supported by the referenced field type')
    end
  end

  it 'keeps accepting a schema with no logic at all' do
    expect(described_class.new(anamnese)).to be_valid
  end
end
