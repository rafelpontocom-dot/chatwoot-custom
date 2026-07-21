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
        'won_amount_cents' => 250_00,
        'lost_amount_cents' => 50_00
      )
      expect(response.parsed_body['by_stage']).to include(
        hash_including('id' => first_stage.id, 'name' => 'Lead', 'open_count' => 1, 'won_count' => 0, 'lost_count' => 0,
                       'amount_cents' => 100_00, 'overdue_count' => 1, 'stale_count' => 1),
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

    it 'does not expose selected agent boards to non-members' do
      kanban_board.update!(visibility_mode: 'selected_agents')

      get sales_summary_url, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
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

  def sales_summary_url
    "/api/v1/accounts/#{account.id}/kanban_boards/#{kanban_board.id}/reports/sales_summary"
  end
end
