require 'rails_helper'

RSpec.describe 'Kanban appointment reminder rules API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:board) { create(:kanban_board, account: account) }
  let(:stage) { create(:kanban_stage, account: account, kanban_board: board) }

  def rules_url
    "/api/v1/accounts/#{account.id}/kanban_boards/#{board.id}/appointment_reminder_rules"
  end

  it 'creates and lists a stage-triggered appointment reminder rule' do
    post rules_url,
         headers: administrator.create_new_auth_token,
         params: {
           appointment_reminder_rule: {
             trigger_type: 'stage_entered',
             trigger_stage_id: stage.id,
             field_key: 'system_starts_at',
             offsets: [48, 24],
             channels: ['whatsapp'],
             message_templates: { '24' => 'Sua consulta está próxima.' },
             active: true
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include(
      'trigger_type' => 'stage_entered',
      'trigger_stage_id' => stage.id,
      'offsets' => [48, 24]
    )

    get rules_url, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.size).to eq(1)
  end

  it 'rejects a stage trigger without a stage' do
    post rules_url,
         headers: administrator.create_new_auth_token,
         params: {
           appointment_reminder_rule: {
             trigger_type: 'stage_entered',
             field_key: 'system_starts_at',
             offsets: [24],
             channels: ['whatsapp']
           }
         },
         as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end
end
