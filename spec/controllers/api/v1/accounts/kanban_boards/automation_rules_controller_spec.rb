require 'rails_helper'

RSpec.describe 'Kanban automation rules API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:board) { create(:kanban_board, account: account) }
  let!(:stage) { create(:kanban_stage, account: account, kanban_board: board) }

  def rules_url
    "/api/v1/accounts/#{account.id}/kanban_boards/#{board.id}/automation_rules"
  end

  it 'allows administrators to create and list a commercial rule' do
    post rules_url,
         headers: administrator.create_new_auth_token,
         params: {
           kanban_automation_rule: {
             name: 'Qualificar oportunidade',
             event_name: Events::Types::KANBAN_CARD_STAGE_CHANGED,
             conditions: { stage_ids: [stage.id] },
             actions: [{ action_name: 'set_next_action', action_params: { next_action_type: 'Cobrar retorno' } }]
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include('name' => 'Qualificar oportunidade', 'active' => true)

    get rules_url, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.first['event_name']).to eq(Events::Types::KANBAN_CARD_STAGE_CHANGED)
  end

  it 'persists a visual workflow definition' do
    flow_definition = {
      nodes: [
        { id: 'trigger', type: 'trigger', position: { x: 0, y: 0 }, data: { event_name: Events::Types::KANBAN_CARD_STAGE_CHANGED } },
        { id: 'wait', type: 'delay', position: { x: 280, y: 0 }, data: { delay_hours: 24 } },
        { id: 'end', type: 'end', position: { x: 560, y: 0 }, data: {} }
      ],
      edges: [{ id: 'trigger-wait', source: 'trigger', target: 'wait' }, { id: 'wait-end', source: 'wait', target: 'end' }]
    }

    post rules_url,
         headers: administrator.create_new_auth_token,
         params: {
           kanban_automation_rule: {
             name: 'Lembrete visual',
             event_name: Events::Types::KANBAN_CARD_STAGE_CHANGED,
             flow_definition: flow_definition
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body['flow_definition']).to eq(flow_definition.deep_stringify_keys)
    expect(response.parsed_body['version']).to eq(1)
  end

  it 'keeps immutable rule versions and restores a selected version' do
    rule = create(:kanban_automation_rule, account: account, kanban_board: board, name: 'Primeira versão')
    rule.record_version!
    first_version = rule.kanban_automation_rule_versions.first
    rule.update!(name: 'Segunda versão')
    rule.record_version!

    get "#{rules_url}/#{rule.id}/versions", headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.map { |version| version['version'] }).to eq([2, 1])

    post "#{rules_url}/#{rule.id}/versions/#{first_version.id}/restore", headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(rule.reload.name).to eq('Primeira versão')
    expect(rule.kanban_automation_rule_versions.count).to eq(3)
  end

  it 'rejects a stale edit instead of overwriting a newer automation rule' do
    rule = create(:kanban_automation_rule, account: account, kanban_board: board, name: 'Versão atual')
    stale_lock_version = rule.lock_version
    rule.update!(name: 'Atualizada por outro administrador')

    patch "#{rules_url}/#{rule.id}",
          headers: administrator.create_new_auth_token,
          params: {
            kanban_automation_rule: {
              name: 'Edição antiga',
              event_name: rule.event_name,
              lock_version: stale_lock_version
            }
          },
          as: :json

    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body['message']).to eq('This automation changed while you were editing it.')
    expect(rule.reload.name).to eq('Atualizada por outro administrador')
  end

  it 'rejects rule configuration for agents' do
    post rules_url,
         headers: agent.create_new_auth_token,
         params: { kanban_automation_rule: { name: 'Regra', event_name: Events::Types::KANBAN_CARD_WON } },
         as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'tests a rule against an opportunity without executing actions' do
    card = create(:kanban_card, account: account, kanban_board: board, kanban_stage: stage)
    rule = create(
      :kanban_automation_rule,
      account: account,
      kanban_board: board,
      conditions: { stage_ids: [stage.id] }
    )

    post "#{rules_url}/#{rule.id}/test",
         headers: administrator.create_new_auth_token,
         params: { card_id: card.id },
         as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('matches' => true, 'card_id' => card.id)
    expect(KanbanAutomationExecution.count).to eq(0)
  end

  it 'previews the visual workflow without changing the opportunity' do
    card = create(:kanban_card, account: account, kanban_board: board, kanban_stage: stage, subject: 'Teste visual')
    rule = create(
      :kanban_automation_rule,
      account: account,
      kanban_board: board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          { id: 'archive', type: 'action', data: { action_name: 'archive_card', action_params: {} } },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'archive' },
          { source: 'archive', target: 'end' }
        ]
      }
    )

    post "#{rules_url}/#{rule.id}/test",
         headers: administrator.create_new_auth_token,
         params: { card_id: card.id },
         as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['steps']).to include(hash_including('node_id' => 'archive', 'action_name' => 'archive_card'))
    expect(card.reload).to be_active
  end

  it 'cancels an individual waiting execution' do
    rule = create(:kanban_automation_rule, account: account, kanban_board: board)
    execution = create(
      :kanban_automation_execution,
      account: account,
      kanban_automation_rule: rule,
      status: 'waiting',
      scheduled_at: 1.day.from_now
    )

    post "#{rules_url}/#{rule.id}/executions/#{execution.id}/cancel",
         headers: administrator.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('status' => 'skipped')
    expect(execution.reload).to have_attributes(status: 'skipped', scheduled_at: nil)
  end

  it 'can cancel waiting executions when an administrator changes a rule' do
    rule = create(:kanban_automation_rule, account: account, kanban_board: board, name: 'Cobrar retorno')
    waiting_execution = create(
      :kanban_automation_execution,
      account: account,
      kanban_automation_rule: rule,
      status: 'waiting',
      scheduled_at: 1.day.from_now
    )

    patch "#{rules_url}/#{rule.id}",
          headers: administrator.create_new_auth_token,
          params: {
            kanban_automation_rule: {
              name: 'Cobrar retorno atualizado',
              event_name: rule.event_name,
              cancel_waiting_executions: true
            }
          },
          as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('waiting_executions_count' => 0)
    expect(waiting_execution.reload).to have_attributes(status: 'skipped', scheduled_at: nil)
    expect(waiting_execution.action_results).to include(hash_including('reason' => 'cancelled_after_rule_update'))
  end

  it 'lists board executions and lets an administrator start a rule manually' do
    card = create(:kanban_card, account: account, kanban_board: board, kanban_stage: stage)
    rule = create(:kanban_automation_rule, account: account, kanban_board: board)
    execution = create(
      :kanban_automation_execution,
      account: account,
      kanban_automation_rule: rule,
      kanban_card: card,
      status: 'failed'
    )

    get "#{rules_url}/executions", headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.first).to include('id' => execution.id, 'card_id' => card.id)

    expect do
      post "#{rules_url}/#{rule.id}/run",
           headers: administrator.create_new_auth_token,
           params: { card_id: card.id },
           as: :json
    end.to have_enqueued_job(KanbanAutomations::ExecuteRuleJob)

    expect(response).to have_http_status(:accepted)
  end

  it 'returns historical node metrics without operational payloads' do
    rule = create(:kanban_automation_rule, account: account, kanban_board: board)
    create(
      :kanban_automation_execution,
      account: account,
      kanban_automation_rule: rule,
      action_results: [
        { 'node_id' => 'message', 'action_name' => 'send_message', 'status' => 'succeeded', 'content' => 'private' },
        { 'node_id' => 'message', 'action_name' => 'send_message', 'status' => 'failed', 'authorization' => 'secret' },
        { 'node_id' => 'wait', 'type' => 'delay', 'status' => 'waiting' }
      ]
    )

    get "#{rules_url}/metrics", headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq(
      [
        { 'node_type' => 'send_message', 'total' => 2, 'failed' => 1 },
        { 'node_type' => 'delay', 'total' => 1, 'failed' => 0 }
      ]
    )
  end

  it 'returns only safe step details in the execution history' do
    rule = create(:kanban_automation_rule, account: account, kanban_board: board)
    create(
      :kanban_automation_execution,
      account: account,
      kanban_automation_rule: rule,
      status: 'failed',
      action_results: [
        {
          'node_id' => 'message',
          'action_name' => 'send_message',
          'status' => 'skipped',
          'reason' => 'no_compatible_conversation',
          'conversation' => { 'id' => 20, 'contact' => { 'email' => 'private@example.com' } },
          'authorization' => 'secret-token'
        }
      ]
    )

    get "#{rules_url}/executions", headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.first['action_results']).to eq(
      [
        {
          'node_id' => 'message',
          'action_name' => 'send_message',
          'status' => 'skipped',
          'reason' => 'no_compatible_conversation'
        }
      ]
    )
  end
end
