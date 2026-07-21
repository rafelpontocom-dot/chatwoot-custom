require 'rails_helper'

RSpec.describe 'Kanban saved filters API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:board) { create(:kanban_board, account: account) }
  let(:path) { "/api/v1/accounts/#{account.id}/kanban_boards/#{board.id}/saved_filters" }

  it 'creates and lists filters only for the current user' do
    other_user = create(:user, account: account)
    create(:kanban_saved_filter, account: account, kanban_board: board, user: other_user)

    post path,
         headers: agent.create_new_auth_token,
         params: {
           saved_filter: {
             name: 'Atrasadas de alto valor',
             filters: { next_action: 'overdue', sort: 'amount_desc', search: 'Premium' }
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include(
      'name' => 'Atrasadas de alto valor',
      'filters' => include('next_action' => 'overdue', 'sort' => 'amount_desc', 'search' => 'Premium')
    )

    get path, headers: agent.create_new_auth_token, as: :json

    expect(response.parsed_body.pluck('name')).to eq(['Atrasadas de alto valor'])
  end

  it 'updates and removes a personal saved filter' do
    filter = create(:kanban_saved_filter, account: account, kanban_board: board, user: agent)

    patch "#{path}/#{filter.id}",
          headers: agent.create_new_auth_token,
          params: { saved_filter: { name: 'Meu funil', filters: { status: 'open' } } },
          as: :json

    expect(response).to have_http_status(:success)
    expect(filter.reload).to have_attributes(name: 'Meu funil', filters: { 'status' => 'open' })

    delete "#{path}/#{filter.id}", headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:no_content)
    expect(KanbanSavedFilter.exists?(filter.id)).to be(false)
  end

  it 'does not expose another user filter' do
    filter = create(:kanban_saved_filter, account: account, kanban_board: board)

    delete "#{path}/#{filter.id}", headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:not_found)
  end
end
