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

    expect(response.parsed_body['recent'].first.keys).to match_array(%w[id command_type state occurred_at])
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
end
