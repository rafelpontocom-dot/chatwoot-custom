require 'rails_helper'

RSpec.describe 'Calendar procedure booking settings', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:procedure) { KanbanCalendarProcedure.create!(account: account, name: 'Avaliação com laser CO2', duration_minutes: 50) }
  let(:url) { "/api/v1/accounts/#{account.id}/calendar/procedures/#{procedure.id}" }

  it 'saves limits, payment, change policy and booking questions of the procedure' do
    questions = [
      { key: 'full_name', label: 'Nome completo', kind: 'text', required: true, locked: true },
      { key: 'whatsapp', label: 'WhatsApp', kind: 'phone', required: 'true' },
      { key: 'cpf', label: 'CPF', kind: 'cpf', required: 'feegow' }
    ]

    patch url, params: { procedure: {
      minimum_notice_minutes: 1440, maximum_notice_days: 60, slot_interval_minutes: 30, daily_limit: 4,
      payment_enabled: true, price_cents: 25_000, payment_mode: 'full', payment_methods: %w[pix card], hold_minutes: 10,
      reschedule_allowed: true, change_deadline_hours: 12, on_cancel_stage_action: 'mark_lost',
      public_booking_config: { questions: questions }
    } }, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    body = response.parsed_body
    expect(body.slice('minimum_notice_minutes', 'price_cents', 'payment_methods', 'on_cancel_stage_action'))
      .to eq('minimum_notice_minutes' => 1440, 'price_cents' => 25_000, 'payment_methods' => %w[pix card], 'on_cancel_stage_action' => 'mark_lost')
    expect(body['booking_questions'].pluck('key', 'required')).to eq([['full_name', true], ['whatsapp', true], %w[cpf feegow]])
  end

  it 'refuses questions that drop the full name, and a deposit bigger than the price' do
    patch url, params: { procedure: { public_booking_config: { questions: [{ key: 'email', label: 'E-mail', kind: 'email', required: false }] } } },
               headers: administrator.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)

    patch url, params: { procedure: { payment_enabled: true, price_cents: 10_000, payment_mode: 'deposit', deposit_cents: 20_000 } },
               headers: administrator.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'previews the next days as the public page would show them, naming who attends' do
    anna = KanbanCalendarResource.create!(account: account, name: 'Dra. Anna', resource_type: 'user', timezone: 'America/Sao_Paulo')
    sala = KanbanCalendarResource.create!(account: account, name: 'Sala 1', resource_type: 'room', timezone: 'America/Sao_Paulo')
    procedure.update!(kanban_calendar_resources: [anna, sala], slot_interval_minutes: 60)

    get "#{url}/availability_preview", params: { days: 7 }, headers: administrator.create_new_auth_token

    day = response.parsed_body['days'].first
    expect(day['slots'].first['resources']).to eq(['Dra. Anna', 'Sala 1'])
  end
end
