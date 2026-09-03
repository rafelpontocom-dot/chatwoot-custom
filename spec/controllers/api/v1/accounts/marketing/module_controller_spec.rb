require 'rails_helper'

RSpec.describe 'Marketing module API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:module_path) { "/api/v1/accounts/#{account.id}/marketing/module" }

  it 'answers off until somebody turns it on' do
    get module_path, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('enabled' => false)
  end

  it 'records who turned it on' do
    patch module_path,
          headers: administrator.create_new_auth_token,
          params: { marketing_module: { enabled: true } },
          as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('enabled' => true)
    expect(account.reload.marketing_module_setting.enabled_by).to eq(administrator)
  end

  # Desligar para de captar para a conta inteira, e o que se perde nesse
  # intervalo nao volta.
  it 'refuses to turn it off without an explicit confirmation' do
    MarketingModuleSetting.create!(account: account, enabled: true)

    patch module_path,
          headers: administrator.create_new_auth_token,
          params: { marketing_module: { enabled: false } },
          as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(account.reload.marketing_module_setting.enabled).to be(true)
  end

  it 'turns it off when the confirmation comes' do
    MarketingModuleSetting.create!(account: account, enabled: true)

    patch module_path,
          headers: administrator.create_new_auth_token,
          params: { marketing_module: { enabled: false, confirm_disable: true } },
          as: :json

    expect(response).to have_http_status(:success)
    expect(account.reload.marketing_module_setting.enabled).to be(false)
  end

  it 'lets an agent read the state but not change it' do
    get module_path, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)

    patch module_path,
          headers: agent.create_new_auth_token,
          params: { marketing_module: { enabled: true } },
          as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it 'refuses somebody from another account' do
    stranger = create(:user, account: create(:account), role: :administrator)

    get module_path, headers: stranger.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
