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

  describe 'a contact that is not in the account yet' do
    it 'creates it from the e-mail the row brings' do
      resultado = importar({ 'email' => 'novo@clinica.pt', 'assunto' => 'Botox' })

      expect(resultado).to be_ok
      expect(resultado.card.contact.email).to eq('novo@clinica.pt')
    end

    it 'uses the name column when the file has one' do
      resultado = importar({ 'email' => 'novo@clinica.pt', 'nome' => 'Joana', 'assunto' => 'Botox' })

      expect(resultado.card.contact.name).to eq('Joana')
    end

    it 'takes the name from the column the screen paired' do
      resultado = importar(
        { 'email' => 'novo@clinica.pt', 'Nome Completo' => 'Joana Dias', 'assunto' => 'X' },
        mapping: { 'Nome Completo' => described_class::NATIVE_CONTACT_NAME }
      )

      expect(resultado.card.contact.name).to eq('Joana Dias')
    end

    it 'refuses a row with nothing to identify the person by' do
      resultado = importar({ 'assunto' => 'Botox' })

      expect(resultado).not_to be_ok
      expect(resultado.error).to include('no e-mail or phone')
    end

    it 'reports the invalid phone on the row instead of aborting the import' do
      resultado = importar({ 'telefone' => 'não é telefone', 'assunto' => 'Botox' })

      expect(resultado).not_to be_ok
      expect(resultado.error).to be_present
    end
  end

  describe 'not creating the same person twice' do
    it 'matches a phone written without the country code against the stored one' do
      contact.update!(phone_number: '+5562999990000')

      expect { importar({ 'telefone' => '62999990000', 'assunto' => 'X' }) }
        .not_to change(Contact, :count)
    end

    it 'reuses the contact found by e-mail instead of creating another' do
      expect { importar({ 'email' => 'maria@clinica.pt', 'assunto' => 'X' }) }
        .not_to change(Contact, :count)
    end
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

  describe 'columns paired with a native field' do
    it 'reads the amount from a column that is not named like ours' do
      resultado = importar(
        { 'email' => 'maria@clinica.pt', 'assunto' => 'X', 'Valor da Proposta' => 'R$ 1.250,50' },
        mapping: { 'Valor da Proposta' => described_class::NATIVE_AMOUNT }
      )

      expect(resultado.card.amount_cents).to eq(125_050)
    end

    it 'reads the stage from a column that is not named like ours' do
      resultado = importar(
        { 'email' => 'maria@clinica.pt', 'assunto' => 'X', 'Fase do Funil' => 'consulta agendada' },
        mapping: { 'Fase do Funil' => described_class::NATIVE_STAGE }
      )

      expect(resultado.card.kanban_stage).to eq(agendado)
    end

    it 'reads the subject from a column that is not named like ours' do
      resultado = importar(
        { 'email' => 'maria@clinica.pt', 'Descricao do Negocio' => 'Botox' },
        mapping: { 'Descricao do Negocio' => described_class::NATIVE_SUBJECT }
      )

      expect(resultado.card.subject).to eq('Botox')
    end

    it 'finds the contact through a mapped email column' do
      resultado = importar(
        { 'Correio Electronico' => 'maria@clinica.pt', 'assunto' => 'X' },
        mapping: { 'Correio Electronico' => described_class::NATIVE_EMAIL }
      )

      expect(resultado.card.contact).to eq(contact)
    end

    it 'finds the contact through a mapped phone column' do
      contact.update!(phone_number: '+5562999990000')
      resultado = importar(
        { 'Contacto Movel' => '+5562999990000', 'assunto' => 'X' },
        mapping: { 'Contacto Movel' => described_class::NATIVE_PHONE }
      )

      expect(resultado.card.contact).to eq(contact)
    end

    it 'lets the explicit pairing win over a column named like ours' do
      resultado = importar(
        { 'email' => 'maria@clinica.pt', 'assunto' => 'X', 'valor' => 'R$ 10,00', 'Valor Real' => 'R$ 99,00' },
        mapping: { 'Valor Real' => described_class::NATIVE_AMOUNT }
      )

      expect(resultado.card.amount_cents).to eq(9_900)
    end

    it 'falls back to the column name when nothing was paired' do
      resultado = importar({ 'email' => 'maria@clinica.pt', 'assunto' => 'X', 'valor' => 'R$ 10,00' })

      expect(resultado.card.amount_cents).to eq(1_000)
    end

    it 'keeps a native pairing out of the custom field values' do
      resultado = importar(
        { 'email' => 'maria@clinica.pt', 'assunto' => 'X', 'Valor da Proposta' => 'R$ 1.250,50' },
        mapping: { 'Valor da Proposta' => described_class::NATIVE_AMOUNT }
      )

      expect(resultado.card.custom_field_values).to eq({})
    end
  end
end
