require 'rails_helper'

RSpec.describe KanbanCards::RowImporter do
  let(:account) { create(:account) }
  let(:board) { create(:kanban_board, account: account) }
  let!(:novo) { create(:kanban_stage, account: account, kanban_board: board, name: 'Novo', position: 1) }
  let!(:agendado) { create(:kanban_stage, account: account, kanban_board: board, name: 'Consulta agendada', position: 2) }
  let!(:contact) { create(:contact, account: account, name: 'Maria', email: 'maria@clinica.pt') }

  before { create(:inbox, account: account) }

  def importar(row, mapping: {})
    described_class.new(board: board, fallback_stage: novo, mapping: mapping).import(row)
  end

  it 'links the row to the contact that is already there' do
    resultado = importar({ 'email' => 'maria@clinica.pt', 'assunto' => 'Botox' })

    expect(resultado).to be_ok
    expect(resultado.card.contact).to eq(contact)
    expect(resultado.card.subject).to eq('Botox')
  end

  it 'refuses a row whose contact is not in the account yet' do
    resultado = importar({ 'email' => 'ninguem@clinica.pt', 'assunto' => 'Botox' })

    expect(resultado).not_to be_ok
    expect(resultado.error).to include('import the contacts first')
  end

  it 'puts the row in the stage the file names' do
    resultado = importar({ 'email' => 'maria@clinica.pt', 'assunto' => 'X', 'etapa' => 'consulta agendada' })

    expect(resultado.card.kanban_stage).to eq(agendado)
  end

  it 'falls back instead of losing the row to a misspelled stage' do
    resultado = importar({ 'email' => 'maria@clinica.pt', 'assunto' => 'X', 'etapa' => 'Xpto' })

    expect(resultado.card.kanban_stage).to eq(novo)
  end

  it 'reads an amount written the way people write it here' do
    resultado = importar({ 'email' => 'maria@clinica.pt', 'assunto' => 'X', 'valor' => 'R$ 1.250,50' })

    expect(resultado.card.amount_cents).to eq(125_050)
  end

  it 'uses the contact name when the file has no subject' do
    resultado = importar({ 'email' => 'maria@clinica.pt' })

    expect(resultado.card.subject).to eq('Maria')
  end

  it 'maps the columns the screen paired with fields' do
    # O cartão descarta valores de campos que o funil não define, e bem.
    board.update!(custom_field_definitions: [
                    { 'key' => 'valor_orcado', 'label' => 'Valor orçado', 'field_type' => 'text' }
                  ])
    resultado = importar(
      { 'email' => 'maria@clinica.pt', 'assunto' => 'X', 'Vlr Orcado' => '450' },
      mapping: { 'Vlr Orcado' => 'valor_orcado' }
    )

    expect(resultado.card.custom_field_values).to eq('valor_orcado' => '450')
  end

  it 'finds the contact by phone when there is no email' do
    contact.update!(phone_number: '+5562999990000')
    resultado = importar({ 'telefone' => '+5562999990000', 'assunto' => 'X' })

    expect(resultado.card.contact).to eq(contact)
  end
end
