require 'rails_helper'

RSpec.describe 'Finance webhook deliveries API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:setting) { FinanceModuleSetting.create!(account: account, enabled: true, market: 'BR') }
  let!(:connection) do
    FinanceProviderConnection.create!(
      account: account,
      provider: 'asaas',
      environment: 'sandbox',
      api_key: 'asaas-test-key',
      status: 'attention'
    )
  end
  let!(:delivery) do
    FinanceWebhookDelivery.create!(
      account: account,
      finance_provider_connection: connection,
      provider_event_id: 'evt_001',
      payload_digest: Digest::SHA256.hexdigest('{"id":"evt_001"}'),
      raw_payload: '{"id":"evt_001"}',
      processing_status: 'failed',
      error_message: 'Webhook processing failed: ActiveRecord::RecordNotFound',
      received_at: Time.current
    )
  end
  let(:base_path) do
    "/api/v1/accounts/#{account.id}/finance/provider_connections/#{connection.id}/webhook_deliveries"
  end

  before { setting }

  it 'lists safe webhook delivery metadata without the provider payload' do
    get base_path, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to contain_exactly(
      include(
        'id' => delivery.id,
        'processing_status' => 'failed',
        'error_message' => 'Webhook processing failed: ActiveRecord::RecordNotFound'
      )
    )
    expect(response.parsed_body.first).not_to have_key('raw_payload')
  end

  it 'reprocesses a failed webhook delivery as an administrator' do
    service = instance_double(Finance::Asaas::RetryWebhookDeliveryService, perform: delivery)
    allow(Finance::Asaas::RetryWebhookDeliveryService).to receive(:new).with(delivery: delivery).and_return(service)

    post "#{base_path}/#{delivery.id}/retry", headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(service).to have_received(:perform)
  end
end
