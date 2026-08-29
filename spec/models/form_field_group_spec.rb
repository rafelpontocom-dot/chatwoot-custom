require 'rails_helper'

RSpec.describe FormFieldGroup do
  let(:account) { create(:account) }
  let(:section) do
    {
      'key' => 'dados_iniciais',
      'title' => 'Dados iniciais',
      'fields' => [
        { 'key' => 'nome', 'label' => 'Nome completo', 'type' => 'text', 'required' => true }
      ]
    }
  end

  it 'stores a reusable section scoped to an account' do
    group = described_class.create!(account: account, name: 'Identificação', section: section)

    expect(group.admin_payload).to include(name: 'Identificação', section: section)
  end

  it 'rejects an invalid field structure' do
    group = described_class.new(
      account: account,
      name: 'Incompleto',
      section: { 'key' => 'incompleto', 'fields' => [{ 'key' => 'sem_rotulo', 'type' => 'text' }] }
    )

    expect(group).not_to be_valid
    expect(group.errors[:section]).to include('fields must define a key, label, and supported type')
  end
end
