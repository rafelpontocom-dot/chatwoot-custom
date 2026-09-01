require 'rails_helper'

RSpec.describe Forms::AnswersValidator do
  let(:schema) do
    {
      'sections' => [
        {
          'key' => 'principal',
          'fields' => [
            { 'key' => 'valor', 'type' => 'currency', 'label' => 'Valor' },
            { 'key' => 'quantidade', 'type' => 'number', 'label' => 'Quantidade' },
            { 'key' => 'data', 'type' => 'date', 'label' => 'Data' },
            { 'key' => 'horario', 'type' => 'datetime', 'label' => 'Horário' }
          ]
        }
      ]
    }
  end

  it 'rejects invalid typed answers sent outside the browser controls' do
    validator = described_class.new(
      schema: schema,
      answers: { valor: 'R$ 20', quantidade: 'muitas', data: 'amanhã', horario: 'depois do almoço' }
    )

    expect(validator).not_to be_valid
    expect(validator.errors).to include(
      'Valor precisa ser um número válido',
      'Quantidade precisa ser um número válido',
      'Data precisa ser uma data válida',
      'Horário precisa ser uma data e hora válida'
    )
  end

  it 'accepts valid typed answers' do
    validator = described_class.new(
      schema: schema,
      answers: { valor: '20.50', quantidade: '2', data: '2026-08-28', horario: '2026-08-28T14:30' }
    )

    expect(validator).to be_valid
  end

  it 'accepts a typed visual acceptance signature' do
    validator = described_class.new(
      schema: {
        'sections' => [
          {
            'key' => 'aceite',
            'fields' => [
              {
                'key' => 'assinatura_paciente',
                'type' => 'signature',
                'label' => 'Digite seu nome',
                'required' => true
              }
            ]
          }
        ]
      },
      answers: { assinatura_paciente: 'Pedro Raevo' }
    )

    expect(validator).to be_valid
  end

  it 'returns only visible non-hidden answers for persistence' do
    validator = described_class.new(
      schema: {
        'sections' => [
          {
            'key' => 'principal',
            'fields' => [
              { 'key' => 'deseja_contato', 'type' => 'select', 'label' => 'Deseja contato?', 'options' => %w[sim nao] },
              {
                'key' => 'telefone',
                'type' => 'phone',
                'label' => 'Telefone',
                'visible_when' => { 'field' => 'deseja_contato', 'operator' => 'equals', 'value' => 'sim' }
              },
              { 'key' => 'origem_tecnica', 'type' => 'hidden', 'label' => 'Origem técnica', 'required' => true }
            ]
          }
        ]
      },
      answers: { deseja_contato: 'nao', telefone: '+5511999999999' }
    )

    expect(validator).to be_valid
    expect(validator.permitted_answers).to eq('deseja_contato' => 'nao')
  end

  describe 'respostas vindas do formulário público' do
    let(:consent_schema) do
      {
        'sections' => [{
          'key' => 's',
          'fields' => [
            { 'key' => 'declaracao', 'type' => 'consent', 'label' => 'Declaro', 'required' => true }
          ]
        }]
      }
    end

    it 'accepts a consent that arrived as text' do
      validator = described_class.new(schema: consent_schema, answers: { 'declaracao' => 'true' })

      expect(validator).to be_valid
      # Persiste booleano, não a string: é assim que a resposta fica legível
      # para quem a ler daqui a dois anos.
      expect(validator.permitted_answers['declaracao']).to be(true)
    end

    it 'says the consent must be accepted, not that it is blank' do
      validator = described_class.new(schema: consent_schema, answers: { 'declaracao' => 'false' })

      expect(validator).not_to be_valid
      expect(validator.errors.first).to include('precisa ser aceito')
    end

    context 'when the consent is optional' do
      let(:optional_schema) do
        {
          'sections' => [{
            'key' => 's',
            'fields' => [
              { 'key' => 'novidades', 'type' => 'consent', 'label' => 'Quero receber novidades', 'required' => false }
            ]
          }]
        }
      end

      # Recusar uma newsletter é uma resposta. Se bloqueasse o envio, um campo
      # acessório impediria a pessoa de entregar o formulário todo.
      it 'lets the submission through when it is declined' do
        validator = described_class.new(schema: optional_schema, answers: { 'novidades' => 'false' })

        expect(validator).to be_valid
        expect(validator.permitted_answers['novidades']).to be(false)
      end

      it 'lets the submission through when it is left untouched' do
        expect(described_class.new(schema: optional_schema, answers: {})).to be_valid
      end

      it 'still refuses a value that is no answer at all' do
        validator = described_class.new(schema: optional_schema, answers: { 'novidades' => 'talvez' })

        expect(validator).not_to be_valid
        expect(validator.errors.first).to include('precisa ser aceito ou recusado')
      end
    end
  end
end
