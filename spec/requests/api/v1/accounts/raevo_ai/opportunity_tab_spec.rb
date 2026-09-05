require 'rails_helper'

RSpec.describe 'Raevo AI opportunity tab API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:board) { create(:kanban_board, account: account) }
  let(:integration) do
    RaevoAiIntegration.create!(
      account: account,
      clinic_id: 'clinic-demo',
      enabled: true,
      settings: { 'crm' => { 'boards' => { 'acquisition' => { 'board_id' => board.id, 'fields' => {} } } } }
    )
  end
  let(:path) { "/api/v1/accounts/#{account.id}/raevo_ai/opportunity_tab" }

  it 'lets an administrator enable the standard AI tab on a CRM-published board' do
    integration

    patch path,
          params: { enabled: true, board_ids: [board.id] },
          headers: administrator.create_new_auth_token,
          as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq('enabled' => true, 'board_ids' => [board.id])
    expect(board.reload.configured_custom_field_definitions).to include(hash_including('key' => 'raevo_ai_summary'))
  end

  it 'lets an administrator configure the tab while the integration is disabled' do
    disabled_integration = RaevoAiIntegration.create!(
      account: account,
      clinic_id: 'clinic-disabled',
      enabled: false,
      settings: { 'crm' => { 'boards' => { 'acquisition' => { 'board_id' => board.id, 'fields' => {} } } } }
    )

    patch path,
          params: { enabled: true, board_ids: [board.id] },
          headers: administrator.create_new_auth_token,
          as: :json

    expect(response).to have_http_status(:ok)
    expect(disabled_integration.reload).to have_attributes(enabled: false)
    expect(board.reload.configured_custom_field_definitions).to include(hash_including('key' => 'raevo_ai_summary'))
  end

  it 'does not expose the configuration to a user from another account' do
    integration
    outsider = create(:user, account: create(:account), role: :administrator)

    get path, headers: outsider.create_new_auth_token, as: :json

    expect(response).not_to have_http_status(:success)
  end
end
