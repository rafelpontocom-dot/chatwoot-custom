require 'rails_helper'

RSpec.describe 'Marketing lead intake API', type: :request do
  let(:account) { create(:account) }
  let(:kanban_board) { create(:kanban_board, account: account) }
  let(:kanban_stage) { create(:kanban_stage, account: account, kanban_board: kanban_board) }
  let(:inbox) { create(:inbox, account: account) }
  let(:source) do
    account.marketing_intake_sources.create!(
      name: 'Landing',
      crm_destination: {
        'kanban_board_id' => kanban_board.id,
        'kanban_stage_id' => kanban_stage.id,
        'inbox_id' => inbox.id
      }
    )
  end
  let(:headers) { { 'X-Raevo-Intake-Token' => source.token } }
  let(:lead) do
    { name: 'Paciente', phone_number: '11987650001', utm_source: 'google', utm_medium: 'cpc', gclid: 'G1' }
  end

  before { MarketingModuleSetting.create!(account: account, enabled: true) }

  describe 'GET /public/api/v1/marketing/intake/schema' do
    it 'tells an integrator exactly what it accepts' do
      get '/public/api/v1/marketing/intake/schema', headers: headers, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body.dig('fields', 'contact')).to include('phone_number')
      expect(body.dig('fields', 'attribution')).to include('utm_source', 'gclid', 'fbclid')
      expect(body['source']).to eq('Landing')
    end
  end

  describe 'POST /public/api/v1/marketing/intake' do
    it 'creates the contact and the opportunity' do
      expect do
        post '/public/api/v1/marketing/intake', params: lead, headers: headers, as: :json
      end.to change(KanbanCard, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['status']).to eq('created')
      card = KanbanCard.find(response.parsed_body['opportunity_id'])
      expect(card.kanban_stage_id).to eq(kanban_stage.id)
    end

    it 'records where the lead came from' do
      post '/public/api/v1/marketing/intake', params: lead, headers: headers, as: :json

      touchpoint = MarketingTouchpoint.last
      expect(touchpoint.payload).to include('gclid' => 'G1', 'origem_do_lead' => 'Mídia Paga')
    end

    # n8n repete, a página é recarregada, a plataforma reentrega.
    it 'treats a retry as the same lead' do
      post '/public/api/v1/marketing/intake', params: lead.merge(idempotency_key: 'k1'), headers: headers, as: :json
      primeira = response.parsed_body['opportunity_id']

      expect do
        post '/public/api/v1/marketing/intake', params: lead.merge(idempotency_key: 'k1'), headers: headers, as: :json
      end.not_to change(KanbanCard, :count)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('status' => 'duplicate', 'opportunity_id' => primeira)
    end

    it 'refuses a lead with no way to identify the person' do
      post '/public/api/v1/marketing/intake', params: { utm_source: 'google' }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('contact_identity_required')
    end

    it 'ignores fields outside the catalogue' do
      post '/public/api/v1/marketing/intake',
           params: lead.merge(password: 'secret', account_id: 999), headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(MarketingTouchpoint.last.payload).not_to have_key('password')
    end

    context 'when the caller has no business being here' do
      it 'refuses an unknown token' do
        post '/public/api/v1/marketing/intake', params: lead,
                                                headers: { 'X-Raevo-Intake-Token' => 'nope' }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'refuses with no token at all' do
        post '/public/api/v1/marketing/intake', params: lead, as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      # Revogar tem de valer na hora, sem esperar deploy nem expiração.
      it 'refuses a source that was switched off' do
        source.update!(active: false)

        post '/public/api/v1/marketing/intake', params: lead, headers: headers, as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'refuses when the account turned the module off' do
        account.marketing_module_setting.update!(enabled: false)

        post '/public/api/v1/marketing/intake', params: lead, headers: headers, as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'stops a flood on one token' do
        allow_any_instance_of(Marketing::IntakeRateLimiter).to receive(:allowed?).and_return(false) # rubocop:disable RSpec/AnyInstance

        post '/public/api/v1/marketing/intake', params: lead, headers: headers, as: :json

        expect(response).to have_http_status(:too_many_requests)
      end
    end

    it 'refuses when the destination no longer exists' do
      kanban_board.update!(active: false)

      post '/public/api/v1/marketing/intake', params: lead, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('destination_unavailable')
    end
  end
end
