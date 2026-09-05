require 'rails_helper'

RSpec.describe 'Raevo AI integration API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:path) { "/api/v1/accounts/#{account.id}/raevo_ai/integration" }

  it 'creates a disabled integration for an administrator' do
    post path,
         params: { clinic_id: 'clinic-demo' },
         headers: administrator.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include('clinic_id' => 'clinic-demo', 'enabled' => false)
    expect(account.reload.raevo_ai_integration).to have_attributes(clinic_id: 'clinic-demo', enabled: false)
  end
end
