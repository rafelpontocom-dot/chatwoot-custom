require 'rails_helper'

RSpec.describe 'Marketing intake deliveries', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:base_path) { "/api/v1/accounts/#{account.id}/marketing/intake_deliveries" }
  let(:board) { create(:kanban_board, account: account) }
  let(:stage) { create(:kanban_stage, account: account, kanban_board: board) }
  let(:inbox) { create(:inbox, account: account) }
  let(:source) do
    account.marketing_intake_sources.create!(
      name: 'Landing',
      crm_destination: {
        'kanban_board_id' => board.id,
        'kanban_stage_id' => stage.id,
        'inbox_id' => inbox.id
      }
    )
  end
  let!(:delivery) do
    MarketingWebhookDelivery.create!(
      account: account,
      marketing_intake_source: source,
      provider: 'intake',
      processing_status: 'failed',
      payload_digest: SecureRandom.hex(32),
      raw_payload: { name: 'Paciente', phone_number: '11999999999' }.to_json,
      received_at: Time.current,
      error_message: 'destination_unavailable'
    )
  end

  before { MarketingModuleSetting.create!(account: account, enabled: true) }

  it 'lists the auditable intake result without exposing its raw patient payload' do
    get base_path, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['payload'].first).to include(
      'id' => delivery.id,
      'source_name' => 'Landing',
      'processing_status' => 'failed',
      'error_message' => 'destination_unavailable'
    )
    expect(response.body).not_to include('11999999999', 'Paciente')
  end

  it 'only returns deliveries belonging to the current account' do
    other_account = create(:account)
    MarketingWebhookDelivery.create!(
      account: other_account, provider: 'intake', processing_status: 'failed',
      payload_digest: SecureRandom.hex(32), raw_payload: '{}', received_at: Time.current
    )

    get base_path, headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['payload'].pluck('id')).to eq([delivery.id])
  end

  it 'queues a manual retry for a failed intake' do
    expect do
      post "#{base_path}/#{delivery.id}/retry", headers: admin.create_new_auth_token, as: :json
    end.to have_enqueued_job(Marketing::ProcessIntakeDeliveryJob).with(delivery.id)

    expect(response).to have_http_status(:accepted)
    expect(delivery.reload).to have_attributes(processing_status: 'received', error_message: nil)
  end
end
