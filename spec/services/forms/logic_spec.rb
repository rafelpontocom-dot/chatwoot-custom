require 'rails_helper'

RSpec.describe Forms::Logic do
  describe '.operators_for' do
    it 'gives each field type only the operators that make sense for it' do
      expect(described_class.operators_for('text')).to include('starts_with', 'contains')
      expect(described_class.operators_for('number')).to include('greater_than')
      expect(described_class.operators_for('number')).not_to include('starts_with')
      expect(described_class.operators_for('date')).to include('is_before', 'is_after')
      expect(described_class.operators_for('multi_select')).to include('contains')
      expect(described_class.operators_for('select')).not_to include('contains')
    end

    it 'always allows asking whether the question was answered' do
      %w[text number date signature attachment hidden].each do |type|
        expect(described_class.operators_for(type)).to include('is_empty', 'is_not_empty')
      end
    end

    it 'gives an unknown type nothing but the common operators' do
      expect(described_class.operators_for('inventado')).to eq(%w[is_empty is_not_empty])
    end
  end

  describe '.matches?' do
    it 'compares text' do
      expect(described_class.matches?('is', 'Sim', 'Sim')).to be(true)
      expect(described_class.matches?('is', ' Sim ', 'Sim')).to be(true)
      expect(described_class.matches?('is_not', 'Não', 'Sim')).to be(true)
      expect(described_class.matches?('contains', 'dor de cabeça', 'cabeça')).to be(true)
      expect(described_class.matches?('starts_with', 'Isotretinoína', 'Iso')).to be(true)
      expect(described_class.matches?('ends_with', 'Isotretinoína', 'ína')).to be(true)
    end

    it 'treats a multiple choice answer as a set, not as text' do
      answer = %w[Anticoagulante Corticoide]

      # «contém» é a opção estar entre as escolhidas; «é» é o conjunto exato.
      expect(described_class.matches?('contains', answer, 'Anticoagulante')).to be(true)
      expect(described_class.matches?('does_not_contain', answer, 'Isotretinoína')).to be(true)
      expect(described_class.matches?('is', answer, %w[Corticoide Anticoagulante])).to be(true)
      expect(described_class.matches?('is', answer, ['Anticoagulante'])).to be(false)
    end

    it 'compares numbers as numbers, and accepts a decimal comma' do
      expect(described_class.matches?('greater_than', '10', '2')).to be(true)
      expect(described_class.matches?('greater_than', '9', '10')).to be(false)
      expect(described_class.matches?('less_or_equal_than', '2,5', '2.5')).to be(true)
      expect(described_class.matches?('equal', 3, '3')).to be(true)
    end

    it 'compares dates chronologically' do
      expect(described_class.matches?('is_before', '2026-01-10', '2026-02-01')).to be(true)
      expect(described_class.matches?('is_after', '2026-03-01', '2026-02-01')).to be(true)
    end

    it 'knows whether the question was answered' do
      expect(described_class.matches?('is_empty', '', nil)).to be(true)
      expect(described_class.matches?('is_empty', [], nil)).to be(true)
      expect(described_class.matches?('is_empty', ['', nil], nil)).to be(true)
      expect(described_class.matches?('is_not_empty', 'Sim', nil)).to be(true)
    end

    it 'answers false instead of raising when the comparison cannot apply' do
      # Isto corre no meio da submissão de um paciente: levantar aqui derrubaria
      # o envio inteiro por causa de uma regra mal montada.
      expect(described_class.matches?('greater_than', 'abc', '2')).to be(false)
      expect(described_class.matches?('is_before', 'ontem', '2026-01-01')).to be(false)
      expect(described_class.matches?('inventado', 'Sim', 'Sim')).to be(false)
    end
  end
end
