require 'rails_helper'

RSpec.describe 'Raevo AI activity API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:path) { "/api/v1/accounts/#{account.id}/raevo_ai/activity" }
  let(:integration) { RaevoAiIntegration.create!(account: account, clinic_id: 'clinic-anna-alice', enabled: true) }

  def record_command(type, state, action_id, created_at: Time.current)
    integration.raevo_ai_commands.create!(
      action_id: action_id, command_type: type, payload_digest: Digest::SHA256.hexdigest(action_id),
      state: state, created_at: created_at
    )
  end

  it 'returns an empty feed when the account has no integration' do
    get path, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq('recent' => [], 'attention' => { 'failed' => 0, 'pending' => 0 })
  end

  it 'lists what the assistant did, newest first' do
    record_command('crm.ensure_opportunity', 'applied', 'a1')
    record_command('handoff.apply', 'applied', 'a2')

    get path, headers: administrator.create_new_auth_token, as: :json

    expect(response.parsed_body['recent'].pluck('command_type')).to eq(%w[handoff.apply crm.ensure_opportunity])
  end

  it 'never exposes the internal receipt of a command' do
    record_command('calendar.book_appointment', 'applied', 'a1')

    get path, headers: administrator.create_new_auth_token, as: :json

    expect(response.parsed_body['recent'].first.keys).to match_array(%w[id command_type state occurred_at target])
  end

  it 'counts what needs a person: failures and commands left claimed' do
    record_command('crm.move_stage', 'failed_terminal', 'a1')
    record_command('crm.update_fields', 'failed_retryable', 'a2')
    record_command('finance.create_charge', 'claimed', 'a3', created_at: 10.minutes.ago)
    record_command('crm.add_label', 'applied', 'a4')

    get path, headers: administrator.create_new_auth_token, as: :json

    expect(response.parsed_body['attention']).to eq('failed' => 2, 'pending' => 1)
  end

  it 'does not call work in progress a pending item' do
    # Um comando acabado de reclamar está a decorrer. Acusá-lo de imediato
    # ensinava a clínica a ignorar o aviso.
    record_command('finance.create_charge', 'claimed', 'a1')

    get path, headers: administrator.create_new_auth_token, as: :json

    expect(response.parsed_body['attention']).to eq('failed' => 0, 'pending' => 0)
  end

  it 'never shows a command type it does not recognise' do
    comando = record_command('crm.add_label', 'applied', 'a1')
    # Salta a validação de propósito: o caso a cobrir é uma linha gravada antes
    # da allowlist existir, que por definição não passaria por ela agora.
    comando.update_column(:command_type, 'algo.que.nao.conhecemos') # rubocop:disable Rails/SkipsModelValidations

    get path, headers: administrator.create_new_auth_token, as: :json

    expect(response.parsed_body['recent'].first['command_type']).to eq('unknown')
  end

  it 'refuses to record a command type that is not on the list' do
    expect { record_command('algo.inventado', 'applied', 'a1') }
      .to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'only shows the commands of the account making the request' do
    record_command('crm.ensure_opportunity', 'applied', 'a1')
    outra = RaevoAiIntegration.create!(account: create(:account), clinic_id: 'outra-clinica', enabled: true)
    outra.raevo_ai_commands.create!(action_id: 'b1', command_type: 'handoff.apply', payload_digest: 'x', state: 'applied')

    get path, headers: administrator.create_new_auth_token, as: :json

    expect(response.parsed_body['recent'].length).to eq(1)
  end

  it 'lets an agent read the feed' do
    record_command('crm.ensure_opportunity', 'applied', 'a1')

    get path, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
  end

  it 'gives the feed somewhere to open without ever exposing the receipt' do
    conversation = create(:conversation, account: account)
    comando = record_command('crm.ensure_opportunity', 'applied', 'a1')
    comando.update!(result: { 'conversation_id' => conversation.display_id, 'board_key' => 'vendas' })

    get path, headers: administrator.create_new_auth_token, as: :json

    linha = response.parsed_body['recent'].first
    expect(linha['target']).to eq('type' => 'conversation', 'id' => conversation.display_id)
    expect(linha).not_to have_key('result')
    expect(response.body).not_to include('board_key')
  end

  it 'offers no destination when the receipt names a conversation of another account' do
    alheia = create(:conversation, account: create(:account))
    comando = record_command('crm.ensure_opportunity', 'applied', 'a1')
    comando.update!(result: { 'conversation_id' => alheia.display_id })

    get path, headers: administrator.create_new_auth_token, as: :json

    expect(response.parsed_body['recent'].first['target']).to be_nil
  end

  it 'opens the opportunity when the command recorded a card instead of a conversation' do
    # Metade dos executores grava o cartão e não a conversa. Sem aceitar os
    # dois, metade do feed ficava sem botão e a linha não levava a lado nenhum.
    board = create(:kanban_board, account: account)
    stage = create(:kanban_stage, account: account, kanban_board: board, name: 'Novo', position: 1)
    inbox = create(:inbox, account: account)
    card = create(:kanban_card, account: account, kanban_board: board, kanban_stage: stage,
                                contact: create(:contact, account: account), inbox: inbox)
    comando = record_command('crm.move_stage', 'applied', 'a1')
    comando.update!(result: { 'card_id' => card.id, 'receipts' => { 'stage' => { 'status' => 'applied' } } })

    get path, headers: administrator.create_new_auth_token, as: :json

    linha = response.parsed_body['recent'].first
    expect(linha['target']).to eq('type' => 'card', 'id' => card.id, 'board_id' => board.id)
    expect(response.body).not_to include('receipts')
  end

  it 'offers no destination when the card belongs to another account' do
    outra = create(:account)
    board = create(:kanban_board, account: outra)
    stage = create(:kanban_stage, account: outra, kanban_board: board, name: 'Novo', position: 1)
    alheio = create(:kanban_card, account: outra, kanban_board: board, kanban_stage: stage,
                                  contact: create(:contact, account: outra), inbox: create(:inbox, account: outra))
    comando = record_command('crm.move_stage', 'applied', 'a1')
    comando.update!(result: { 'card_id' => alheio.id })

    get path, headers: administrator.create_new_auth_token, as: :json

    expect(response.parsed_body['recent'].first['target']).to be_nil
  end
end
