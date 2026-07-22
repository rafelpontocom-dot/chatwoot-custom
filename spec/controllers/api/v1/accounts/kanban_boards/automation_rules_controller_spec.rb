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
end
