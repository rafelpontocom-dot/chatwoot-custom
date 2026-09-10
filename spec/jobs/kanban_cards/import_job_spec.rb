require 'rails_helper'

RSpec.describe KanbanCards::ImportJob do
  let(:account) { create(:account) }
  let(:board) { create(:kanban_board, account: account) }

  before do
    create(:kanban_stage, account: account, kanban_board: board, name: 'Novo', position: 1)
    create(:inbox, account: account)
    create(:contact, account: account, name: 'Maria', email: 'maria@clinica.pt')
  end

  def importar(csv, meta: {})
    data_import = DataImport.new(account: account, data_type: 'kanban_cards',
                                 meta: { 'board_id' => board.id }.merge(meta))
    data_import.import_file.attach(io: StringIO.new(csv), filename: 'op.csv', content_type: 'text/csv')
    data_import.save!
    described_class.perform_now(data_import)
    data_import.reload
  end

  it 'imports the rows it can and reports the ones it cannot' do
    # A segunda linha não tem por onde identificar a pessoa. A terceira traz um
    # e-mail que ainda não está na conta, e essa entra: o contacto é criado.
    resultado = importar(
      "email,assunto\nmaria@clinica.pt,Botox\n,Preenchimento\nninguem@clinica.pt,Peeling\n"
    )

    expect(resultado).to be_completed
    expect(resultado.processed_records).to eq(2)
    expect(resultado.total_records).to eq(3)
    expect(board.kanban_cards.pluck(:subject)).to match_array(%w[Botox Peeling])
  end

  it 'hands the rejected rows back with the reason' do
    resultado = importar("email,assunto\n,X\n")

    expect(resultado.failed_records).to be_attached
    expect(resultado.failed_records.download).to include('no e-mail or phone')
  end

  it 'attaches nothing when every row went in' do
    resultado = importar("email,assunto\nmaria@clinica.pt,Botox\n")

    expect(resultado.failed_records).not_to be_attached
    expect(resultado.processed_records).to eq(1)
  end

  it 'fails loudly when the funnel is gone instead of importing nowhere' do
    resultado = importar("email,assunto\nmaria@clinica.pt,X\n", meta: { 'board_id' => 0 })

    expect(resultado).to be_failed
    expect(board.kanban_cards).to be_empty
  end
end
