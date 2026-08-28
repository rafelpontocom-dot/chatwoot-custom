require 'rails_helper'

RSpec.describe Finance::Asaas::ProcessWebhookService do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:connection) do
    FinanceProviderConnection.create!(
      account: account,
      provider: 'asaas',
      environment: 'sandbox',
      api_key: 'asaas-test-key',
      webhook_token: 'a' * 32,
      status: 'connected'
    )
  end
  let!(:payment) do
    FinancePayment.create!(
      account: account,
      contact: contact,
      finance_provider_connection: connection,
      provider_payment_id: 'pay_001',
      external_reference: 'payment-42',
      amount_cents: 15_025,
      billing_type: 'pix',
      status: 'pending'
    )
  end
  let(:payload) do
    {
      id: 'evt_001',
      event: 'PAYMENT_RECEIVED',
      dateCreated: '2026-08-27 10:30:00',
      payment: {
        id: 'pay_001',
        status: 'RECEIVED',
        invoiceUrl: 'https://pay.example/1',
        paymentDate: '2026-08-27'
      }
    }
  end

  it 'updates the payment and records the provider event once' do
    expect do
      described_class.new(connection: connection, payload: payload).perform
    end.to change(FinancePaymentEvent, :count).by(1)

    expect(payment.reload).to have_attributes(status: 'received', invoice_url: 'https://pay.example/1')
    expect(payment.finance_payment_events.last).to have_attributes(provider_event_id: 'evt_001', event_type: 'PAYMENT_RECEIVED')
  end

  it 'restores the connection health after a valid provider event' do
    connection.update!(status: 'attention', last_error: 'Webhook processing failed: ActiveRecord::RecordNotFound')

    described_class.new(connection: connection, payload: payload).perform

    expect(connection.reload).to have_attributes(status: 'connected', last_error: nil, last_webhook_at: be_present)
  end

  it 'does not process a repeated Asaas event twice' do
    service = described_class.new(connection: connection, payload: payload)
    payment.update!(kanban_card: create(:kanban_card, account: account, contact: contact))
    allow(Rails.configuration.dispatcher).to receive(:dispatch)
    service.perform

    expect { service.perform }.not_to change(FinancePaymentEvent, :count)
    expect(Rails.configuration.dispatcher).to have_received(:dispatch).once
  end

  it 'keeps an out-of-order provider event for audit without regressing the payment state' do
    payment.update!(status: 'received', paid_at: Time.zone.parse('2026-08-27 08:00:00'))
    outdated_payload = payload.merge(id: 'evt_overdue', event: 'PAYMENT_OVERDUE').deep_merge(
      payment: { status: 'OVERDUE' }
    )
    allow(Rails.configuration.dispatcher).to receive(:dispatch)

    described_class.new(connection: connection, payload: outdated_payload).perform

    expect(payment.reload).to have_attributes(status: 'received', paid_at: Time.zone.parse('2026-08-27 08:00:00'))
    expect(payment.finance_payment_events.last).to have_attributes(
      provider_event_id: 'evt_overdue',
      event_type: 'PAYMENT_OVERDUE',
      processing_status: 'ignored'
    )
    expect(Rails.configuration.dispatcher).not_to have_received(:dispatch)
  end

  it 'dispatches a safe financial event for an opportunity-linked payment' do
    card = create(:kanban_card, account: account, contact: contact)
    payment.update!(kanban_card: card)
    allow(Rails.configuration.dispatcher).to receive(:dispatch)

    described_class.new(connection: connection, payload: payload).perform

    expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
      Events::Types::FINANCE_PAYMENT_RECEIVED,
      kind_of(ActiveSupport::TimeWithZone),
      hash_including(
        account_id: account.id,
        board_id: card.kanban_board_id,
        card_id: card.id,
        payment_id: payment.id,
        payment_status: 'received',
        payment_amount_cents: 15_025,
        payment_currency: 'BRL'
      )
    )
  end

  it 'keeps the provider creation webhook for audit without dispatching a second creation event' do
    payment.finance_payment_events.create!(
      account: account,
      finance_provider_connection: connection,
      event_type: 'PAYMENT_CREATED',
      occurred_at: Time.current,
      metadata: { source: 'asaas_create' }
    )
    created_payload = payload.merge(id: 'evt_created', event: 'PAYMENT_CREATED')
    allow(Rails.configuration.dispatcher).to receive(:dispatch)

    described_class.new(connection: connection, payload: created_payload).perform

    expect(payment.finance_payment_events.where(event_type: 'PAYMENT_CREATED').count).to eq(2)
    expect(Rails.configuration.dispatcher).not_to have_received(:dispatch)
  end
end
