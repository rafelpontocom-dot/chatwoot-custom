require 'rails_helper'

RSpec.describe 'Raevo AI calendar commands API', type: :request do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:board) { create(:kanban_board, account: account, calendar_enabled: true) }
  let(:stage) { create(:kanban_stage, account: account, kanban_board: board, name: 'Scheduling') }
  let(:card) do
    create(
      :kanban_card,
      :conversation_origin,
      account: account,
      kanban_board: board,
      kanban_stage: stage,
      conversation: conversation
    )
  end
  let(:procedure) do
    KanbanCalendarProcedure.create!(
      account: account,
      name: 'Initial consultation',
      duration_minutes: 50,
      recurrence_allowed: false
    )
  end
  let(:resource) do
    KanbanCalendarResource.create!(
      account: account,
      name: 'Virtual room',
      resource_type: 'room',
      timezone: 'America/Sao_Paulo'
    )
  end
  let(:token) { 'a' * 64 }
  let(:integration) do
    board.update!(calendar_procedure_ids: [procedure.id])
    RaevoAiIntegration.create!(
      account: account,
      clinic_id: 'clinic-demo',
      enabled: true,
      settings: {
        'command_token_digest' => Digest::SHA256.hexdigest(token),
        'crm' => { 'boards' => { 'acquisition' => { 'board_id' => board.id } } },
        'calendar' => {
          'bookings' => {
            'initial_consultation' => {
              'board_key' => 'acquisition',
              'procedure_id' => procedure.id,
              'resource_ids' => [resource.id],
              'timezone' => 'America/Sao_Paulo'
            }
          }
        }
      }
    )
  end
  let(:headers) { { 'X-Raevo-Clinic-Id' => integration.clinic_id, 'X-Raevo-Command-Token' => token } }

  it 'books only the catalog-published procedure and resource for the trusted conversation opportunity' do
    card
    before_count = KanbanCalendarAppointment.count
    post '/public/api/v1/raevo_ai/calendar/bookings', params: {
      action_id: 'turn-100:booking:initial-consultation',
      conversation_id: conversation.display_id,
      board_key: 'acquisition',
      booking_key: 'initial_consultation',
      starts_at: '2026-10-01T13:00:00-03:00',
      timezone: 'America/Sao_Paulo',
      procedure_id: 999_999,
      resource_ids: [999_999]
    }, headers: headers, as: :json

    expect(response).to have_http_status(:ok), response.body
    expect(KanbanCalendarAppointment.count).to eq(before_count + 1)
    appointment = KanbanCalendarAppointment.last
    expect(appointment).to have_attributes(
      account: account,
      contact: conversation.contact,
      kanban_card: card,
      kanban_calendar_procedure: procedure
    )
    expect(appointment.kanban_calendar_appointment_resources.pluck(:kanban_calendar_resource_id)).to eq([resource.id])
    expect(response.parsed_body).to eq(
      'action_id' => 'turn-100:booking:initial-consultation',
      'status' => 'applied',
      'receipts' => {
        'appointment' => {
          'status' => 'created',
          'appointment_id' => appointment.id,
          'starts_at' => appointment.starts_at.iso8601
        }
      }
    )
  end

  it 'replays the command receipt without booking another appointment' do
    card
    params = {
      action_id: 'turn-100:booking:initial-consultation',
      conversation_id: conversation.display_id,
      board_key: 'acquisition',
      booking_key: 'initial_consultation',
      starts_at: '2026-10-01T13:00:00-03:00',
      timezone: 'America/Sao_Paulo'
    }

    post '/public/api/v1/raevo_ai/calendar/bookings', params: params, headers: headers, as: :json

    expect do
      post '/public/api/v1/raevo_ai/calendar/bookings', params: params, headers: headers, as: :json
    end.not_to change(KanbanCalendarAppointment, :count)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('receipts', 'appointment', 'status')).to eq('created')
  end

  it 'rejects a booking key that the tenant did not publish' do
    post '/public/api/v1/raevo_ai/calendar/bookings', params: {
      action_id: 'turn-100:booking:unpublished',
      conversation_id: conversation.display_id,
      board_key: 'acquisition',
      booking_key: 'unpublished',
      starts_at: '2026-10-01T13:00:00-03:00',
      timezone: 'America/Sao_Paulo'
    }, headers: headers, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body).to eq('error' => 'invalid_catalog')
    expect(KanbanCalendarAppointment.all).to be_empty
  end
end
