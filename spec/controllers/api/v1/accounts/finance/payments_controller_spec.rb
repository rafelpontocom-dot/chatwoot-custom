require 'rails_helper'

RSpec.describe 'Finance payments API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }
  let(:payments_path) { "/api/v1/accounts/#{account.id}/finance/payments" }
  let(:setting) { FinanceModuleSetting.create!(account: account, enabled: true, market: 'BR') }
  let!(:connection) do
    FinanceProviderConnection.create!(
      account: account,
      provider: 'asaas',
      environment: 'sandbox',
      api_key: 'asaas-test-key',
      status: 'connected'
    )
  end

  before { setting }

  it 'creates a payment link from a contact' do
    payment = instance_double(FinancePayment, public_payload: { id: 12, status: 'pending' })
    service = instance_double(Finance::Asaas::CreatePaymentService, perform: payment)
    expect(Finance::Asaas::CreatePaymentService).to receive(:new).with(
      connection: connection,
      contact: contact,
      kanban_card: nil,
      actor: administrator,
      amount_cents: 15_025,
      billing_type: 'pix',
      due_on: '2026-08-31',
      cpf_cnpj: '12345678909',
      description: 'Consulta',
      currency: 'BRL'
    ).and_return(service)

    post payments_path,
         headers: administrator.create_new_auth_token,
         params: {
           payment: {
             contact_id: contact.id,
             finance_provider_connection_id: connection.id,
             amount_cents: 15_025,
             billing_type: 'pix',
             due_on: '2026-08-31',
             cpf_cnpj: '12345678909',
             description: 'Consulta'
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include('id' => 12, 'status' => 'pending')
  end

  it 'creates a payment link linked to an opportunity' do
    card = create(:kanban_card, account: account, contact: contact)
    payment = instance_double(FinancePayment, public_payload: { id: 14, status: 'pending' })
    service = instance_double(Finance::Asaas::CreatePaymentService, perform: payment)
    allow(Finance::Asaas::CreatePaymentService).to receive(:new).and_return(service)

    post payments_path,
         headers: administrator.create_new_auth_token,
         params: {
           payment: {
             contact_id: contact.id,
             finance_provider_connection_id: connection.id,
             kanban_card_id: card.id,
             amount_cents: 15_025,
             billing_type: 'pix',
             due_on: '2026-08-31',
             cpf_cnpj: '12345678909',
             description: 'Consulta'
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    expect(Finance::Asaas::CreatePaymentService).to have_received(:new).with(
      hash_including(connection: connection, contact: contact, kanban_card: card)
    )
  end

  it 'lets a standard agent create a payment link without finance configuration access' do
    payment = instance_double(FinancePayment, public_payload: { id: 13, status: 'pending' })
    service = instance_double(Finance::Asaas::CreatePaymentService, perform: payment)
    allow(Finance::Asaas::CreatePaymentService).to receive(:new).and_return(service)

    post payments_path,
         headers: agent.create_new_auth_token,
         params: {
           payment: {
             contact_id: contact.id,
             finance_provider_connection_id: connection.id,
             amount_cents: 15_025,
             billing_type: 'pix',
             due_on: '2026-08-31',
             cpf_cnpj: '12345678909',
             description: 'Consulta'
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    expect(Finance::Asaas::CreatePaymentService).to have_received(:new).with(
      hash_including(actor: agent, connection: connection, contact: contact)
    )
  end

  it 'records an external payment through the manual connection' do
    setting.update!(market: 'PT')
    manual_connection = FinanceProviderConnection.create!(
      account: account,
      provider: 'manual',
      environment: 'production',
      status: 'connected'
    )
    payment = instance_double(FinancePayment, public_payload: { id: 13, status: 'pending', currency: 'EUR' })
    service = instance_double(Finance::Manual::CreatePaymentService, perform: payment)
    allow(Finance::Manual::CreatePaymentService).to receive(:new).and_return(service)

    post payments_path,
         headers: administrator.create_new_auth_token,
         params: {
           payment: {
             contact_id: contact.id,
             finance_provider_connection_id: manual_connection.id,
             amount_cents: 9_000,
             billing_type: 'other',
             due_on: '2026-09-04',
             currency: 'EUR',
             description: 'Consulta externa'
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    expect(Finance::Manual::CreatePaymentService).to have_received(:new).with(
      hash_including(connection: manual_connection, contact: contact, amount_cents: 9_000, currency: 'EUR')
    )
  end

  it 'lists the account payments with their contact context' do
    conversation = create(:conversation, account: account, contact: contact)
    card = create(
      :kanban_card,
      account: account,
      contact: contact,
      inbox: conversation.inbox,
      conversation: conversation,
      owner: administrator
    )
    payment = FinancePayment.create!(
      account: account,
      contact: contact,
      kanban_card: card,
      finance_provider_connection: connection,
      external_reference: 'payment-42',
      amount_cents: 15_025,
      billing_type: 'pix',
      status: 'pending'
    )

    get payments_path,
        headers: administrator.create_new_auth_token,
        params: { kanban_card_id: card.id },
        as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.first).to include(
      'id' => payment.id,
      'contact' => include('id' => contact.id, 'name' => contact.name),
      'kanban_card' => include(
        'id' => card.id,
        'conversation_id' => conversation.id,
        'owner' => include('id' => administrator.id, 'name' => administrator.name)
      )
    )
  end

  it 'does not return charges from another opportunity' do
    card = create(:kanban_card, account: account, contact: contact)
    other_card = create(:kanban_card, account: account)
    matching_payment = FinancePayment.create!(
      account: account,
      contact: contact,
      kanban_card: card,
      finance_provider_connection: connection,
      external_reference: 'payment-card-1',
      amount_cents: 15_025,
      billing_type: 'pix',
      status: 'pending'
    )
    FinancePayment.create!(
      account: account,
      contact: other_card.contact,
      kanban_card: other_card,
      finance_provider_connection: connection,
      external_reference: 'payment-card-2',
      amount_cents: 20_000,
      billing_type: 'pix',
      status: 'pending'
    )

    get payments_path,
        headers: administrator.create_new_auth_token,
        params: { kanban_card_id: card.id },
        as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to contain_exactly(include('id' => matching_payment.id))
  end

  it 'filters charges by status, due date and linked contact' do
    matching_payment = FinancePayment.create!(
      account: account,
      contact: contact,
      finance_provider_connection: connection,
      external_reference: 'payment-filtered',
      amount_cents: 15_025,
      billing_type: 'pix',
      due_on: Date.new(2026, 9, 10),
      status: 'pending'
    )
    FinancePayment.create!(
      account: account,
      contact: create(:contact, account: account, name: 'Outro contato'),
      finance_provider_connection: connection,
      external_reference: 'payment-not-filtered',
      amount_cents: 20_000,
      billing_type: 'pix',
      due_on: Date.new(2026, 8, 10),
      status: 'received'
    )

    get payments_path,
        headers: administrator.create_new_auth_token,
        params: {
          status: 'pending',
          due_from: '2026-09-01',
          due_to: '2026-09-30',
          query: contact.name
        },
        as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to contain_exactly(include('id' => matching_payment.id))
  end

  it 'filters charges by the commercial owner of their opportunity' do
    matching_card = create(:kanban_card, account: account, contact: contact, owner: administrator)
    matching_payment = FinancePayment.create!(
      account: account,
      contact: contact,
      kanban_card: matching_card,
      finance_provider_connection: connection,
      external_reference: 'payment-owner-filter',
      amount_cents: 15_025,
      billing_type: 'pix',
      status: 'pending'
    )
    FinancePayment.create!(
      account: account,
      contact: create(:contact, account: account),
      kanban_card: create(:kanban_card, account: account),
      finance_provider_connection: connection,
      external_reference: 'payment-without-owner',
      amount_cents: 20_000,
      billing_type: 'pix',
      status: 'pending'
    )

    get payments_path,
        headers: administrator.create_new_auth_token,
        params: { owner_id: administrator.id },
        as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to contain_exactly(include('id' => matching_payment.id))
  end

  it 'returns commercial totals using the same filters as the payment list' do
    FinancePayment.create!(
      account: account,
      contact: contact,
      finance_provider_connection: connection,
      amount_cents: 15_025,
      billing_type: 'pix',
      status: 'pending'
    )
    FinancePayment.create!(
      account: account,
      contact: contact,
      finance_provider_connection: connection,
      amount_cents: 20_000,
      billing_type: 'pix',
      status: 'received'
    )

    get "#{payments_path}/summary",
        headers: administrator.create_new_auth_token,
        params: { query: contact.name },
        as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include(
      'open' => [include('currency' => 'BRL', 'count' => 1, 'amount_cents' => 15_025)],
      'received' => [include('currency' => 'BRL', 'count' => 1, 'amount_cents' => 20_000)],
      'overdue' => []
    )
  end

  it 'shows a payment with a safe event timeline' do
    payment = FinancePayment.create!(
      account: account,
      contact: contact,
      finance_provider_connection: connection,
      external_reference: 'payment-timeline',
      amount_cents: 15_025,
      billing_type: 'pix',
      status: 'received'
    )
    FinancePaymentEvent.create!(
      account: account,
      finance_payment: payment,
      finance_provider_connection: connection,
      provider_event_id: 'evt_001',
      event_type: 'PAYMENT_RECEIVED',
      occurred_at: Time.zone.parse('2026-09-01 10:30:00'),
      metadata: { payment: { customer: 'do-not-expose' } }
    )

    get "#{payments_path}/#{payment.id}",
        headers: administrator.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include(
      'id' => payment.id,
      'events' => [include('event_type' => 'PAYMENT_RECEIVED')]
    )
    expect(response.parsed_body.dig('events', 0)).not_to have_key('metadata')
  end

  it 'cancels a pending payment through the account-scoped service' do
    payment = FinancePayment.create!(
      account: account,
      contact: contact,
      finance_provider_connection: connection,
      external_reference: 'payment-cancel',
      amount_cents: 15_025,
      billing_type: 'pix',
      status: 'pending'
    )
    service = instance_double(Finance::Asaas::CancelPaymentService, perform: payment)
    allow(Finance::Asaas::CancelPaymentService).to receive(:new)
      .with(payment: payment, actor: administrator)
      .and_return(service)

    post "#{payments_path}/#{payment.id}/cancel",
         headers: administrator.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('id' => payment.id, 'status' => 'pending')
  end

  it 'requests an Asaas refund through the account-scoped service' do
    payment = FinancePayment.create!(
      account: account,
      contact: contact,
      finance_provider_connection: connection,
      amount_cents: 15_025,
      billing_type: 'pix',
      status: 'received'
    )
    service = instance_double(Finance::Asaas::RefundPaymentService, perform: payment)
    allow(Finance::Asaas::RefundPaymentService).to receive(:new)
      .with(payment: payment, actor: administrator, description: 'Cobrança duplicada')
      .and_return(service)

    post "#{payments_path}/#{payment.id}/refund",
         headers: administrator.create_new_auth_token,
         params: { refund: { description: 'Cobrança duplicada' } },
         as: :json

    expect(response).to have_http_status(:ok)
    expect(Finance::Asaas::RefundPaymentService).to have_received(:new)
      .with(payment: payment, actor: administrator, description: 'Cobrança duplicada')
  end

  it 'cancels an external payment through the manual service' do
    setting.update!(market: 'PT')
    manual_connection = FinanceProviderConnection.create!(
      account: account,
      provider: 'manual',
      environment: 'production',
      status: 'connected'
    )
    payment = FinancePayment.create!(
      account: account,
      contact: contact,
      finance_provider_connection: manual_connection,
      amount_cents: 9_000,
      billing_type: 'other',
      currency: 'EUR',
      status: 'pending'
    )
    service = instance_double(Finance::Manual::CancelPaymentService, perform: payment)
    allow(Finance::Manual::CancelPaymentService).to receive(:new)
      .with(payment: payment, actor: administrator)
      .and_return(service)

    post "#{payments_path}/#{payment.id}/cancel",
         headers: administrator.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:ok)
    expect(Finance::Manual::CancelPaymentService).to have_received(:new)
      .with(payment: payment, actor: administrator)
  end

  it 'marks an external payment as received through the manual service' do
    setting.update!(market: 'PT')
    manual_connection = FinanceProviderConnection.create!(
      account: account,
      provider: 'manual',
      environment: 'production',
      status: 'connected'
    )
    payment = FinancePayment.create!(
      account: account,
      contact: contact,
      finance_provider_connection: manual_connection,
      amount_cents: 9_000,
      billing_type: 'other',
      currency: 'EUR',
      status: 'pending'
    )
    service = instance_double(Finance::Manual::MarkPaymentReceivedService, perform: payment)
    allow(Finance::Manual::MarkPaymentReceivedService).to receive(:new)
      .with(payment: payment, actor: administrator)
      .and_return(service)

    post "#{payments_path}/#{payment.id}/mark_received",
         headers: administrator.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:ok)
    expect(Finance::Manual::MarkPaymentReceivedService).to have_received(:new)
      .with(payment: payment, actor: administrator)
  end
end
