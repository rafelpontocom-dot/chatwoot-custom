require 'rails_helper'

RSpec.describe 'Kanban Board Reports API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:owner) { create(:user, account: account, name: 'Ana Paula') }
  let(:overdue_owner) { create(:user, account: account, name: 'Carlos') }
  let(:kanban_board) { create(:kanban_board, account: account, name: 'Sales') }
  let!(:first_stage) { create(:kanban_stage, account: account, kanban_board: kanban_board, name: 'Lead', position: 1) }
  let!(:second_stage) { create(:kanban_stage, account: account, kanban_board: kanban_board, name: 'Fechamento', position: 2) }

  describe 'GET /api/v1/accounts/{account.id}/kanban_boards/{kanban_board.id}/reports/sales_summary' do
    it 'returns unauthorized for unauthenticated users' do
      get sales_summary_url

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns the board sales summary for authorized users' do
      create_sales_summary_data

      get sales_summary_url, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include(
        'open_count' => 1,
        'won_count' => 1,
        'lost_count' => 1,
        'overdue_count' => 1,
        'stale_count' => 1,
        'open_amount_cents' => 100_00,
        'weighted_open_amount_cents' => 0,
        'won_amount_cents' => 250_00,
        'lost_amount_cents' => 50_00
      )
      expect(response.parsed_body['by_stage']).to include(
        hash_including('id' => first_stage.id, 'name' => 'Lead', 'probability' => 0, 'open_count' => 1, 'won_count' => 0, 'lost_count' => 0,
                       'amount_cents' => 100_00, 'weighted_amount_cents' => 0, 'overdue_count' => 1, 'stale_count' => 1),
        hash_including('id' => second_stage.id, 'name' => 'Fechamento', 'open_count' => 0, 'won_count' => 1, 'lost_count' => 1,
                       'amount_cents' => 300_00, 'overdue_count' => 0, 'stale_count' => 0)
      )
      expect(response.parsed_body['by_owner']).to include(
        hash_including('id' => owner.id, 'name' => 'Ana Paula', 'open_count' => 0, 'won_count' => 1, 'lost_count' => 0,
                       'amount_cents' => 250_00, 'overdue_count' => 0),
        hash_including('id' => overdue_owner.id, 'name' => 'Carlos', 'open_count' => 1, 'overdue_count' => 1)
      )
      expect(response.parsed_body['lost_reasons']).to include(
        { 'reason' => 'Preço', 'count' => 1, 'amount_cents' => 50_00 }
      )
      expect(response.parsed_body['agenda']).to contain_exactly(
        hash_including('subject' => 'Aberto', 'owner_name' => 'Carlos', 'status' => 'overdue')
      )
    end

    it 'returns the weighted open forecast from stage probabilities' do
      first_stage.update!(probability: 40)
      inbox = create(:inbox, account: account)
      create(
        :kanban_card,
        account: account,
        kanban_board: kanban_board,
        kanban_stage: first_stage,
        contact: create(:contact, account: account),
        inbox: inbox,
        amount_cents: 12_500
      )

      get sales_summary_url, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('weighted_open_amount_cents' => 5_000)
      expect(response.parsed_body['by_stage']).to include(
        hash_including('id' => first_stage.id, 'probability' => 40, 'weighted_amount_cents' => 5_000)
      )
    end

    it 'does not expose selected agent boards to non-members' do
      kanban_board.update!(visibility_mode: 'selected_agents')

      get sales_summary_url, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'requires the commercial report permission for custom roles', if: defined?(CustomRole) do
      custom_role = create(:custom_role, account: account, permissions: ['kanban_view'])
      agent.account_users.find_by(account: account).update!(custom_role: custom_role)

      get sales_summary_url, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body['error']).to include('not authorized')
    end

    it 'allows a custom role with the commercial report permission', if: defined?(CustomRole) do
      custom_role = create(:custom_role, account: account, permissions: %w[kanban_view kanban_report])
      agent.account_users.find_by(account: account).update!(custom_role: custom_role)

      get sales_summary_url, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/kanban_boards/{kanban_board.id}/reports/activities' do
    it 'returns unauthorized for unauthenticated users' do
      get activities_url

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns paginated activities from the complete board dataset' do
      inbox = create(:inbox, account: account)
      create_activity_card(inbox, subject: 'Sem próxima ação')
      create_activity_card(inbox, subject: 'Atrasada', next_action_at: 1.hour.ago)
      create_activity_card(inbox, subject: 'Hoje', next_action_at: 1.hour.from_now)

      get activities_url, params: { view: 'missing', limit: 1 }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['cards'].pluck('subject')).to eq(['Sem próxima ação'])
      expect(response.parsed_body['pagination']).to include(
        'page' => 1,
        'limit' => 1,
        'has_more' => false
      )
    end

    it 'filters activities by owner' do
      inbox = create(:inbox, account: account)
      create_activity_card(inbox, subject: 'Ana activity', owner: owner, next_action_at: 1.hour.ago)
      create_activity_card(inbox, subject: 'Carlos activity', owner: overdue_owner, next_action_at: 1.hour.ago)

      get activities_url, params: { view: 'overdue', owner_id: owner.id }, headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['cards'].pluck('subject')).to eq(['Ana activity'])
    end

    it 'shows only open opportunities in the owner view' do
      inbox = create(:inbox, account: account)
      create_activity_card(inbox, subject: 'Open activity', owner: owner, next_action_at: 1.hour.from_now)
      create(
        :kanban_card,
        account: account,
        kanban_board: kanban_board,
        kanban_stage: first_stage,
        contact: create(:contact, account: account),
        inbox: inbox,
        owner: owner,
        subject: 'Won activity',
        won_at: Time.current
      )

      get activities_url, params: { view: 'owner', owner_id: owner.id }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['cards'].pluck('subject')).to eq(['Open activity'])
    end

    it 'returns open opportunities with appointments ordered by start time' do
      inbox = create(:inbox, account: account)
      create(
        :kanban_card,
        account: account,
        kanban_board: kanban_board,
        kanban_stage: first_stage,
        contact: create(:contact, account: account),
        inbox: inbox,
        subject: 'Mais tarde',
        starts_at: 3.hours.from_now
      )
      create(
        :kanban_card,
        account: account,
        kanban_board: kanban_board,
        kanban_stage: first_stage,
        contact: create(:contact, account: account),
        inbox: inbox,
        subject: 'Primeiro',
        starts_at: 1.hour.from_now
      )
      create(
        :kanban_card,
        account: account,
        kanban_board: kanban_board,
        kanban_stage: first_stage,
        contact: create(:contact, account: account),
        inbox: inbox,
        subject: 'Sem agendamento'
      )
      create(
        :kanban_card,
        account: account,
        kanban_board: kanban_board,
        kanban_stage: first_stage,
        contact: create(:contact, account: account),
        inbox: inbox,
        subject: 'Já ganha',
        starts_at: 2.hours.from_now,
        won_at: Time.current
      )

      get activities_url, params: { view: 'appointments' }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['cards'].pluck('subject')).to eq(['Primeiro', 'Mais tarde'])
      expect(response.parsed_body['cards'].first['starts_at']).to be_present
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/kanban_boards/{kanban_board.id}/reports/export' do
    it 'returns the filtered opportunities as csv' do
      inbox = create(:inbox, account: account)
      export_contact = create(:contact, account: account, name: 'Export Contact', phone_number: '+5511999999999')
      kanban_board.update!(custom_field_definitions: [{ key: 'source', label: 'Origem', field_type: 'text' }])
      create(
        :kanban_card,
        account: account,
        kanban_board: kanban_board,
        kanban_stage: first_stage,
        contact: export_contact,
        inbox: inbox,
        subject: 'Exportada',
        amount_cents: 15_000,
        custom_field_values: { source: 'Google' }
      )
      create(
        :kanban_card,
        account: account,
        kanban_board: kanban_board,
        kanban_stage: first_stage,
        contact: create(:contact, account: account, name: 'Outra Contact'),
        inbox: inbox,
        subject: 'Ganha',
        won_at: Time.current
      )

      get export_url,
          params: { search: 'Exportada', status: 'open', sort: 'amount_desc' },
          headers: administrator.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success), response.body
      expect(response.media_type).to eq('text/csv')
      expect(response.headers['Content-Disposition']).to include('kanban-sales-')
      expect(response.body).to include('Origem', 'Exportada', 'Google')
      expect(response.body).not_to include('Ganha')
    end
  end

  def create_sales_summary_data
    inbox = create(:inbox, account: account)
    kanban_board.update!(stale_stage_thresholds: { first_stage.id.to_s => 3 })

    create_open_card(inbox)
    create_won_card(inbox)
    create_lost_card(inbox)
  end

  def create_open_card(inbox)
    card = create(
      :kanban_card,
      account: account,
      kanban_board: kanban_board,
      kanban_stage: first_stage,
      contact: create(:contact, account: account),
      inbox: inbox,
      subject: 'Aberto',
      amount_cents: 100_00,
      owner: overdue_owner,
      next_action_type: 'Cobrar retorno',
      next_action_at: 1.day.ago
    )
    card.update_column(:stage_entered_at, 5.days.ago) # rubocop:disable Rails/SkipsModelValidations
  end

  def create_won_card(inbox)
    create(
      :kanban_card,
      account: account,
      kanban_board: kanban_board,
      kanban_stage: second_stage,
      contact: create(:contact, account: account),
      inbox: inbox,
      owner: owner,
      subject: 'Ganho',
      amount_cents: 250_00,
      won_at: Time.current
    )
  end

  def create_lost_card(inbox)
    create(
      :kanban_card,
      account: account,
      kanban_board: kanban_board,
      kanban_stage: second_stage,
      contact: create(:contact, account: account),
      inbox: inbox,
      subject: 'Perdido',
      amount_cents: 50_00,
      lost_at: Time.current,
      lost_reason: 'Preço'
    )
  end

  def create_activity_card(inbox, subject:, owner: nil, next_action_at: nil)
    create(
      :kanban_card,
      account: account,
      kanban_board: kanban_board,
      kanban_stage: first_stage,
      contact: create(:contact, account: account),
      inbox: inbox,
      subject: subject,
      owner: owner,
      next_action_at: next_action_at
    )
  end

  def sales_summary_url
    "/api/v1/accounts/#{account.id}/kanban_boards/#{kanban_board.id}/reports/sales_summary"
  end

  def activities_url
    "/api/v1/accounts/#{account.id}/kanban_boards/#{kanban_board.id}/reports/activities"
  end

  def export_url
    "/api/v1/accounts/#{account.id}/kanban_boards/#{kanban_board.id}/reports/export"
  end
end
