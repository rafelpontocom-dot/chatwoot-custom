require 'rails_helper'

RSpec.describe 'Marketing touchpoints API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account) }
  let(:index_path) { "/api/v1/accounts/#{account.id}/marketing/touchpoints" }
  let(:summary_path) { "#{index_path}/summary" }

  context 'when the module is off' do
    it 'refuses to answer' do
      get index_path, headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when the module is on' do
    before { MarketingModuleSetting.create!(account: account, enabled: true) }

    it 'lists the touchpoints, most recent first' do
      create(:marketing_touchpoint, account: account, contact: contact,
                                    payload: { 'utm_campaign' => 'antiga' }, occurred_at: 2.days.ago)
      create(:marketing_touchpoint, account: account, contact: contact,
                                    payload: { 'utm_campaign' => 'recente' }, occurred_at: 1.hour.ago)

      get index_path, headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      campaigns = response.parsed_body['payload'].map { |row| row.dig('payload', 'utm_campaign') }
      expect(campaigns).to eq(%w[recente antiga])
      expect(response.parsed_body.dig('meta', 'total_count')).to eq(2)
    end

    it 'never leaks another account touchpoints' do
      create(:marketing_touchpoint, account: create(:account))

      get index_path, headers: administrator.create_new_auth_token, as: :json

      expect(response.parsed_body['payload']).to be_empty
    end

    it 'reports how many leads arrived with a known origin' do
      create(:marketing_touchpoint, account: account, contact: contact,
                                    payload: { 'origem_do_lead' => 'Mídia Paga' })
      create(:marketing_touchpoint, account: account, contact: nil,
                                    payload: { 'origem_do_lead' => 'Mídia Paga' })

      get summary_path, headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['total']).to eq(2)
      expect(body['identified']).to eq(1)
      expect(body['capture_rate']).to eq(50.0)
      expect(body['by_origin']).to eq('Mídia Paga' => 2)
    end

    it 'filters by source' do
      create(:marketing_touchpoint, account: account, contact: contact, source: 'widget_referer')
      create(:marketing_touchpoint, account: account, contact: contact, source: 'meta_lead_ad')

      get index_path, headers: administrator.create_new_auth_token,
                      params: { source: 'meta_lead_ad' }, as: :json

      expect(response.parsed_body['payload'].map { |row| row['source'] }).to eq(['meta_lead_ad'])
    end
  end
end
