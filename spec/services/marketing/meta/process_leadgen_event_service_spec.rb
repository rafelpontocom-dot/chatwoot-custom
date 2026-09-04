require 'rails_helper'

RSpec.describe Marketing::Meta::ProcessLeadgenEventService do
  let(:account) { create(:account) }
  let(:connection) do
    account.marketing_provider_connections.create!(
      provider: 'meta', external_account_id: 'meta-1', status: 'connected', access_token: 'user-token'
    )
  end
  let(:kanban_board) do
    create(:kanban_board, account: account, custom_field_definitions: [
             { 'key' => 'campaign', 'label' => 'campaign', 'field_type' => 'text', 'options' => [],
               'layout' => { 'section' => 'marketing', 'position' => 1, 'width' => 'half' } },
             { 'key' => 'origem_do_lead', 'label' => 'origem', 'field_type' => 'text', 'options' => [],
               'layout' => { 'section' => 'marketing', 'position' => 2, 'width' => 'half' } }
           ])
  end
  let(:kanban_stage) { create(:kanban_stage, account: account, kanban_board: kanban_board) }
  let(:inbox) { create(:inbox, account: account) }
  let(:lead_form) do
    account.marketing_lead_forms.create!(
      marketing_provider_connection: connection, page_id: 'page-1', external_form_id: 'form-1',
      name: 'Capilar', active: true,
      field_mapping: { 'full_name' => 'name', 'phone_number' => 'phone_number' },
      crm_destination: {
        'kanban_board_id' => kanban_board.id, 'kanban_stage_id' => kanban_stage.id, 'inbox_id' => inbox.id
      }
    )
  end
  let(:delivery) do
    account.marketing_webhook_deliveries.create!(
      payload_digest: SecureRandom.hex, raw_payload: '{}', provider_event_id: 'lead-9', received_at: Time.current
    )
  end
  let(:event) { { 'leadgen_id' => 'lead-9', 'form_id' => 'form-1' } }
  let(:lead) do
    {
      'id' => 'lead-9', 'campaign_name' => 'FUE Setembro', 'campaign_id' => '111',
      'adset_name' => 'Mulheres 30+', 'adset_id' => '222', 'ad_name' => 'Video A', 'ad_id' => '333',
      'field_data' => [
        { 'name' => 'full_name', 'values' => ['Joana Paciente'] },
        { 'name' => 'phone_number', 'values' => ['11988887777'] }
      ]
    }
  end

  before do
    MarketingModuleSetting.create!(account: account, enabled: true)
    allow(Marketing::Meta::PageTokenService).to receive(:new).and_return(
      instance_double(Marketing::Meta::PageTokenService, token: 'page-token')
    )
    allow(Marketing::Meta::GraphClient).to receive(:request).and_return(lead)
    lead_form
  end

  it 'turns a lead into a contact and an opportunity' do
    expect { described_class.new(delivery: delivery, event: event).perform }
      .to change(KanbanCard, :count).by(1)

    contact = Contact.find_by(account: account, name: 'Joana Paciente')
    expect(contact.phone_number).to eq('+5511988887777')
    expect(delivery.reload.processing_status).to eq('processed')
  end

  # Campanha e anúncio não são pergunta do formulário: não passam pelo
  # mapeamento e teriam se perdido se não fossem lidos à parte.
  it 'keeps the campaign and the ad, which no question carries' do
    described_class.new(delivery: delivery, event: event).perform

    card = KanbanCard.last
    expect(card.custom_field_values).to include('campaign' => 'FUE Setembro', 'origem_do_lead' => 'Mídia Paga')
    expect(MarketingTouchpoint.last.payload).to include('ad_id' => '333', 'sub_origem' => '[MP] Meta')
  end

  # Todo lead do Lead Ads e midia paga do Meta, mas a clinica que separa
  # campanha por origem precisa poder dizer outra coisa neste formulario.
  it 'honours the origin chosen on the form over the default' do
    lead_form.update!(
      crm_destination: lead_form.crm_destination.merge(
        'origem_do_lead' => 'Indicação', 'sub_origem' => '[ORG] Instagram'
      )
    )

    described_class.new(delivery: delivery, event: event).perform

    expect(MarketingTouchpoint.last.payload)
      .to include('origem_do_lead' => 'Indicação', 'sub_origem' => '[ORG] Instagram')
    expect(MarketingTouchpoint.last.source).to eq('meta_lead_ad')
  end

  it 'counts the lead against the form it came from' do
    described_class.new(delivery: delivery, event: event).perform

    expect(lead_form.reload.received_count).to eq(1)
    expect(lead_form.last_lead_at).to be_present
  end

  it 'makes a redelivery a no-op' do
    described_class.new(delivery: delivery, event: event).perform

    expect { described_class.new(delivery: delivery, event: event).perform }
      .not_to change(KanbanCard, :count)
  end

  it 'ignores an event for a form that is no longer active' do
    lead_form.update!(active: false)

    described_class.new(delivery: delivery, event: event).perform

    expect(delivery.reload.processing_status).to eq('ignored')
  end

  it 'records the failure and flags the connection when Meta refuses' do
    allow(Marketing::Meta::GraphClient).to receive(:request).and_raise(Marketing::Meta::ApiError, 'boom')

    described_class.new(delivery: delivery, event: event).perform

    expect(delivery.reload.processing_status).to eq('failed')
    expect(delivery.error_message).to include('Marketing::Meta::ApiError')
    expect(connection.reload.status).to eq('attention')
  end
end
