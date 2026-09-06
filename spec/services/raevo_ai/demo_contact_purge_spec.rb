require 'rails_helper'

RSpec.describe RaevoAi::DemoContactPurge do
  subject(:purge) do
    described_class.new(account: account, contact: contact, expected_phone_suffix: '994331748')
  end

  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, name: 'Demo contact', phone_number: '+5531994331748') }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, contact: contact, inbox: inbox) }
  let(:board) { create(:kanban_board, account: account) }
  let(:stage) { create(:kanban_stage, account: account, kanban_board: board) }
  let!(:card) do
    create(
      :kanban_card,
      :conversation_origin,
      account: account,
      kanban_board: board,
      kanban_stage: stage,
      conversation: conversation
    )
  end

  it 'permanently removes the demo conversation and its opportunity while retaining the WhatsApp contact identity' do
    contact.add_labels(['intervencao-humana'])

    result = purge.perform!

    expect(result).to include('contact_id' => contact.id, 'conversations_deleted' => 1, 'opportunities_deleted' => 1)
    expect(Contact.exists?(contact.id)).to be(true)
    expect(contact.reload).to have_attributes(name: '')
    expect(contact.label_list).to be_empty
    expect(Conversation.where(id: conversation.id)).not_to exist
    expect(KanbanCard.where(id: card.id)).not_to exist
    expect(KanbanCardEvent.where(kanban_card_id: card.id)).not_to exist
  end

  it 'fails closed without changing any record when the test contact fingerprint does not match' do
    expect do
      described_class.new(account: account, contact: contact, expected_phone_suffix: '000000000').perform!
    end.to raise_error(described_class::UnsafePurge, 'contact phone suffix does not match the explicit demo target')

    expect(Conversation.where(id: conversation.id)).to exist
    expect(KanbanCard.where(id: card.id)).to exist
  end

  it 'refuses to purge a card linked to a payment' do
    connection = FinanceProviderConnection.create!(
      account: account,
      provider: 'manual',
      environment: 'sandbox',
      status: 'disconnected',
      settings: {}
    )
    FinancePayment.create!(
      account: account,
      contact: contact,
      kanban_card: card,
      finance_provider_connection: connection,
      amount_cents: 100,
      billing_type: 'undefined',
      kind: 'charge',
      status: 'draft',
      provider_payload: {}
    )

    expect { purge.perform! }
      .to raise_error(described_class::UnsafePurge, 'demo contact has protected records: payments')

    expect(Conversation.where(id: conversation.id)).to exist
    expect(KanbanCard.where(id: card.id)).to exist
  end

  it 'removes a locally canceled demonstration payment before deleting its card' do
    connection = FinanceProviderConnection.create!(
      account: account,
      provider: 'manual',
      environment: 'sandbox',
      status: 'disconnected',
      settings: {}
    )
    payment = FinancePayment.create!(
      account: account,
      contact: contact,
      kanban_card: card,
      finance_provider_connection: connection,
      amount_cents: 100,
      billing_type: 'undefined',
      kind: 'charge',
      status: 'canceled',
      provider_payload: {}
    )
    event = payment.finance_payment_events.create!(
      account: account,
      finance_provider_connection: connection,
      event_type: 'PAYMENT_DELETED',
      occurred_at: Time.current,
      metadata: {}
    )

    expect(purge.perform!).to include('opportunities_deleted' => 1, 'payments_deleted' => 1)
    expect(FinancePayment.where(id: payment.id)).not_to exist
    expect(FinancePaymentEvent.where(id: event.id)).not_to exist
    expect(KanbanCard.where(id: card.id)).not_to exist
  end
end
