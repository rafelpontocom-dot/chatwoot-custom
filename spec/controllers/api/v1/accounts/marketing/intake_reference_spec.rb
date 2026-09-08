require 'rails_helper'

RSpec.describe 'Marketing intake reference', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:path) { "/api/v1/accounts/#{account.id}/marketing/intake_sources/reference" }

  before { MarketingModuleSetting.create!(account: account, enabled: true) }

  it 'hands the panel the same contract the public door enforces' do
    get path, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    body = response.parsed_body
    expect(body['token_header']).to eq('X-Raevo-Intake-Token')
    expect(body['path']).to eq('/public/api/v1/marketing/intake')
    expect(body['rate_limit_per_minute']).to eq(Marketing::IntakeRateLimiter::LIMIT)
    expect(body['fields']['contact']).to include('email', 'phone_number')
    expect(body['fields']['attribution']).to include('utm_source', 'gclid', 'fbclid')
    expect(body['notes']['max_value_length']).to eq(Marketing::AttributionFields::MAX_VALUE_LENGTH)
  end

  # A documentação existe para não divergir da porta. Se alguém mudar o header
  # num sítio e não no outro, é aqui que se sabe.
  it 'names the very header the public endpoint authenticates with' do
    board = create(:kanban_board, account: account)
    stage = create(:kanban_stage, account: account, kanban_board: board)
    source = account.marketing_intake_sources.create!(
      name: 'Landing',
      crm_destination: {
        'kanban_board_id' => board.id,
        'kanban_stage_id' => stage.id,
        'inbox_id' => create(:inbox, account: account).id
      }
    )

    get path, headers: admin.create_new_auth_token, as: :json
    documented_header = response.parsed_body['token_header']

    get '/public/api/v1/marketing/intake/schema',
        headers: { documented_header => source.token }, as: :json

    expect(response).to have_http_status(:success)
  end

  it 'stays closed to an account without the marketing module' do
    MarketingModuleSetting.find_by(account: account).update!(enabled: false)

    get path, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:forbidden)
  end
end
