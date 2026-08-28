require 'rails_helper'

RSpec.describe 'Finance module API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:module_path) { "/api/v1/accounts/#{account.id}/finance/module" }

  it 'returns a disabled finance module until an administrator enables it' do
    get module_path, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('enabled' => false, 'market' => 'BR')
  end

  it 'enables the module and records the selected market' do
    patch module_path,
          headers: administrator.create_new_auth_token,
          params: { finance_module: { enabled: true, market: 'BR', default_payment_provider: 'asaas' } },
          as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('enabled' => true, 'market' => 'BR', 'default_payment_provider' => 'asaas')
    expect(account.reload.finance_module_setting.enabled_by).to eq(administrator)
  end

  it 'requires explicit confirmation before disabling an enabled module' do
    setting = FinanceModuleSetting.create!(account: account, enabled: true, market: 'BR')

    patch module_path,
          headers: administrator.create_new_auth_token,
          params: { finance_module: { enabled: false, lock_version: setting.lock_version } },
          as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(account.reload.finance_module_setting).to be_enabled
  end

  it 'prevents an agent from configuring the module' do
    patch module_path,
          headers: agent.create_new_auth_token,
          params: { finance_module: { enabled: true } },
          as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
