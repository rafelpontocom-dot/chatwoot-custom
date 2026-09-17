require 'rails_helper'

RSpec.describe Marketing::ProcessIntakeDeliveryJob do
  let(:account) { create(:account) }
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
  let(:payload) do
    {
      name: 'Paciente recuperado', phone_number: '11987650009',
      utm_source: 'google', idempotency_key: 'landing-retry-1'
    }
  end
  let(:delivery) do
    MarketingWebhookDelivery.create!(
      account: account,
      marketing_intake_source: source,
      provider: 'intake',
      provider_event_id: payload[:idempotency_key],
      processing_status: 'failed',
      payload_digest: Digest::SHA256.hexdigest(payload.to_json),
      raw_payload: payload.to_json,
      received_at: Time.current,
      error_message: 'destination_unavailable'
    )
  end

  it 'reprocesses a failed intake and links the resulting CRM records' do
    described_class.perform_now(delivery.id)

    expect(delivery.reload).to have_attributes(
      processing_status: 'processed',
      retry_count: 1,
      error_message: nil
    )
    expect(delivery.contact).to be_present
    expect(delivery.kanban_card).to be_present
  end

  it 'does nothing when the delivery was already processed' do
    delivery.update!(processing_status: 'processed', processed_at: Time.current)

    expect { described_class.perform_now(delivery.id) }.not_to change(KanbanCard, :count)
    expect(delivery.reload.retry_count).to eq(0)
  end

  it 'schedules another attempt while a destination remains unavailable' do
    board.update!(active: false)

    expect { described_class.perform_now(delivery.id) }
      .to have_enqueued_job(described_class).with(delivery.id)

    expect(delivery.reload).to have_attributes(
      processing_status: 'failed',
      retry_count: 1,
      error_message: 'destination_unavailable'
    )
  end
end
