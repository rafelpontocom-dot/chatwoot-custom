require 'rails_helper'

RSpec.describe KanbanCards::PurgeDeletedJob do
  let(:account) { create(:account) }
  let(:connection) { FinanceProviderConnection.create!(account: account, provider: 'asaas', status: 'disconnected') }
  let!(:expired) { create(:kanban_card, account: account) }
  let!(:recent) { create(:kanban_card, account: account) }
  let!(:open_card) { create(:kanban_card, account: account) }
  let!(:payment) do
    FinancePayment.create!(account: account, contact: expired.contact, finance_provider_connection: connection,
                           amount_cents: 12_500, kanban_card: expired)
  end

  before do
    travel_to(31.days.ago) { expired.archive! }
    travel_to(29.days.ago) { recent.archive! }
  end

  it 'deletes for good only what was deleted more than 30 days ago' do
    described_class.perform_now

    expect(KanbanCard.exists?(expired.id)).to be(false)
    expect(KanbanCardEvent.where(kanban_card_id: expired.id)).to be_empty
    expect(KanbanCard.exists?(recent.id)).to be(true)
    expect(KanbanCard.exists?(open_card.id)).to be(true)
  end

  it 'keeps the charge and only drops its link to the opportunity' do
    described_class.perform_now

    expect(payment.reload.kanban_card_id).to be_nil
  end
end
