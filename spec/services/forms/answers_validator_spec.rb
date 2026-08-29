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
end
