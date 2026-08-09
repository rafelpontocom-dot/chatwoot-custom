require 'rails_helper'

RSpec.describe 'Calendar booking page API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }

  it 'returns the account booking page with an opaque public token' do
    get "/api/v1/accounts/#{account.id}/calendar/booking_page",
        headers: administrator.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'active' => false,
      'duplicate_policy' => 'create_new'
    )
    expect(response.parsed_body.fetch('public_token')).to match(/\A[a-zA-Z0-9_-]{20,}\z/)
  end

  it 'updates the CRM destination and booking window' do
    board = create(:kanban_board, account: account)
    stage = create(:kanban_stage, account: account, kanban_board: board)
    inbox = create(:inbox, account: account)

    patch "/api/v1/accounts/#{account.id}/calendar/booking_page",
          headers: administrator.create_new_auth_token,
          params: {
            booking_page: {
              active: true,
              title: 'Agenda da clinica',
              duplicate_policy: 'open_or_recent',
              minimum_notice_minutes: 120,
              maximum_notice_days: 30,
              slot_interval_minutes: 30,
              kanban_board_id: board.id,
              kanban_stage_id: stage.id,
              inbox_id: inbox.id
            }
          },
          as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'active' => true,
      'duplicate_policy' => 'open_or_recent',
      'minimum_notice_minutes' => 120,
      'maximum_notice_days' => 30,
      'slot_interval_minutes' => 30,
      'kanban_board_id' => board.id,
      'kanban_stage_id' => stage.id,
      'inbox_id' => inbox.id
    )
  end
end
