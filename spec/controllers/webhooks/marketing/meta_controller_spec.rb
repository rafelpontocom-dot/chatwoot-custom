require 'rails_helper'

RSpec.describe 'Meta leadgen webhook', type: :request do
  let(:app_secret) { 'app-secret' }
  let(:verify_token) { 'verify-me' }
  let(:account) { create(:account) }
  let(:connection) do
    account.marketing_provider_connections.create!(
      provider: 'meta', external_account_id: 'meta-1', status: 'connected', access_token: 'tok'
    )
  end
  let(:kanban_board) { create(:kanban_board, account: account) }
  let(:kanban_stage) { create(:kanban_stage, account: account, kanban_board: kanban_board) }
  let(:inbox) { create(:inbox, account: account) }
  let(:lead_form) do
    account.marketing_lead_forms.create!(
      marketing_provider_connection: connection, page_id: 'page-1', external_form_id: 'form-1',
      name: 'Capilar', active: true,
      crm_destination: {
        'kanban_board_id' => kanban_board.id, 'kanban_stage_id' => kanban_stage.id, 'inbox_id' => inbox.id
      }
    )
  end
  let(:body) do
    {
      object: 'page',
      entry: [{ id: 'page-1', changes: [{ field: 'leadgen',
                                          value: { leadgen_id: 'lead-9', form_id: 'form-1', page_id: 'page-1' } }] }]
    }.to_json
  end

  def signed_headers(payload, secret = app_secret)
    {
      'X-Hub-Signature-256' => "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, payload)}",
      'CONTENT_TYPE' => 'application/json'
    }
  end

  before do
    MarketingModuleSetting.create!(account: account, enabled: true)
    allow(GlobalConfigService).to receive(:load).and_call_original
    allow(GlobalConfigService).to receive(:load).with('MARKETING_META_APP_SECRET', nil).and_return(app_secret)
    allow(GlobalConfigService).to receive(:load).with('MARKETING_META_VERIFY_TOKEN', nil).and_return(verify_token)
    lead_form
  end

  describe 'GET (subscription handshake)' do
    it 'echoes the challenge back when the token matches' do
      get '/webhooks/marketing/meta',
          params: { 'hub.mode' => 'subscribe', 'hub.verify_token' => verify_token, 'hub.challenge' => '12345' }

      expect(response).to have_http_status(:success)
      expect(response.body).to eq('12345')
    end

    it 'refuses a wrong token' do
      get '/webhooks/marketing/meta',
          params: { 'hub.mode' => 'subscribe', 'hub.verify_token' => 'nope', 'hub.challenge' => '12345' }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST' do
    it 'refuses a payload that is not signed' do
      post '/webhooks/marketing/meta', params: body, headers: { 'CONTENT_TYPE' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'refuses a signature made with the wrong secret' do
      post '/webhooks/marketing/meta', params: body, headers: signed_headers(body, 'wrong')

      expect(response).to have_http_status(:unauthorized)
    end

    it 'records the delivery and hands the fetch to a job' do
      expect do
        post '/webhooks/marketing/meta', params: body, headers: signed_headers(body)
      end.to change(MarketingWebhookDelivery, :count).by(1)
                                                     .and have_enqueued_job(Marketing::ProcessLeadgenEventJob)

      expect(response).to have_http_status(:ok)
      expect(MarketingWebhookDelivery.last.provider_event_id).to eq('lead-9')
    end

    # O Meta reentrega o mesmo evento; a segunda vez nao pode virar outro lead.
    it 'keeps one delivery when the same event arrives twice' do
      post '/webhooks/marketing/meta', params: body, headers: signed_headers(body)

      expect do
        post '/webhooks/marketing/meta', params: body, headers: signed_headers(body)
      end.not_to change(MarketingWebhookDelivery, :count)
    end

    # Responder 4xx faria o Meta reentregar para sempre um formulário que não é nosso.
    it 'answers ok and records nothing for a form we do not know' do
      other = { object: 'page',
                entry: [{ id: 'p', changes: [{ field: 'leadgen',
                                               value: { leadgen_id: 'x', form_id: 'desconhecido' } }] }] }.to_json

      expect do
        post '/webhooks/marketing/meta', params: other, headers: signed_headers(other)
      end.not_to change(MarketingWebhookDelivery, :count)

      expect(response).to have_http_status(:ok)
    end

    it 'ignores a form that was switched off' do
      lead_form.update!(active: false)

      expect do
        post '/webhooks/marketing/meta', params: body, headers: signed_headers(body)
      end.not_to change(MarketingWebhookDelivery, :count)
    end

    it 'ignores changes that are not leadgen' do
      other = { object: 'page', entry: [{ id: 'p', changes: [{ field: 'feed', value: {} }] }] }.to_json

      expect do
        post '/webhooks/marketing/meta', params: other, headers: signed_headers(other)
      end.not_to change(MarketingWebhookDelivery, :count)
    end
  end
end
