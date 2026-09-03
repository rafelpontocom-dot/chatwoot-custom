require 'rails_helper'

RSpec.describe Marketing::SyncLeadFormsSchedulerJob do
  let(:account) { create(:account) }
  let(:connection) do
    account.marketing_provider_connections.create!(
      provider: 'meta', external_account_id: 'meta-1', status: 'connected', access_token: 'tok'
    )
  end

  def lead_form(last_synced_at:, page_id: 'page-1')
    account.marketing_lead_forms.create!(
      marketing_provider_connection: connection, page_id: page_id,
      external_form_id: SecureRandom.hex(4), last_synced_at: last_synced_at
    )
  end

  it 'syncs a form nobody has looked at in hours' do
    lead_form(last_synced_at: 10.hours.ago)

    expect { described_class.perform_now }.to have_enqueued_job(Marketing::SyncLeadFormsJob)
  end

  it 'leaves a form that was just synced alone' do
    lead_form(last_synced_at: 5.minutes.ago)

    expect { described_class.perform_now }.not_to have_enqueued_job(Marketing::SyncLeadFormsJob)
  end

  # Bater na Graph com um token que ja falhou so gasta chamada.
  it 'skips forms whose connection needs attention' do
    lead_form(last_synced_at: 10.hours.ago)
    connection.update!(status: 'attention')

    expect { described_class.perform_now }.not_to have_enqueued_job(Marketing::SyncLeadFormsJob)
  end
end
