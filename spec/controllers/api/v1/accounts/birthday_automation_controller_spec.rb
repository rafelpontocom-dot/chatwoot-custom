require 'rails_helper'

RSpec.describe 'Birthday automation API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  before do
    admin
    agent
  end

  describe 'GET /api/v1/accounts/:account_id/birthday_automation' do
    it 'returns safe defaults before the automation is configured' do
      get "/api/v1/accounts/#{account.id}/birthday_automation", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        'active' => false,
        'delivery_channels' => [],
        'opt_in_attribute_key' => 'birthday_messages_opt_in',
        'message_locale' => 'pt_BR'
      )
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/birthday_automation' do
    it 'requires an administrator' do
      patch "/api/v1/accounts/#{account.id}/birthday_automation", params: {
        birthday_automation: { active: true, delivery_channels: ['whatsapp'] }
      }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it 'persists explicit opt-in and channel configuration' do
      patch "/api/v1/accounts/#{account.id}/birthday_automation", params: {
        birthday_automation: {
          active: true,
          days_before: 2,
          delivery_channels: %w[whatsapp email],
          opt_in_attribute_key: 'birthday_messages_opt_in',
          message_locale: 'pt_PT',
          timezone: 'America/Sao_Paulo',
          send_time: '09:00',
          message_template: 'Parabéns, {{contact_name}}!'
        }
      }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(account.reload.kanban_birthday_automation).to have_attributes(
        active: true,
        days_before: 2,
        delivery_channels: contain_exactly('whatsapp', 'email'),
        opt_in_attribute_key: 'birthday_messages_opt_in',
        message_locale: 'pt_PT'
      )
    end

    it 'rejects an invalid timezone and unsupported channel' do
      patch "/api/v1/accounts/#{account.id}/birthday_automation", params: {
        birthday_automation: {
          timezone: 'not-a-timezone',
          delivery_channels: ['sms']
        }
      }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['errors']).to be_present
    end
  end
end
