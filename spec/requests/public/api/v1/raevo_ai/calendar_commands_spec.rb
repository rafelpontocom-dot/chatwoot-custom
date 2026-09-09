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

  it 'lists slots only from the calendar resources published for the trusted conversation opportunity' do
    card
    date = Date.new(2026, 10, 1)
    resource.kanban_calendar_availability_rules.create!(
      kind: 'weekly_window',
      weekday: date.wday,
      starts_at_local: '09:00',
      ends_at_local: '11:00'
    )

    post '/public/api/v1/raevo_ai/calendar/availability', params: {
      conversation_id: conversation.display_id,
      board_key: 'acquisition',
      booking_key: 'initial_consultation',
      starts_on: date.iso8601,
      ends_on: date.iso8601,
      resource_ids: [999_999]
    }, headers: headers, as: :json

    expect(response).to have_http_status(:ok), response.body
    expect(response.parsed_body).to eq(
      'booking_key' => 'initial_consultation',
      'timezone' => 'America/Sao_Paulo',
      'slots' => [
        '2026-10-01T09:00:00-03:00',
        '2026-10-01T09:15:00-03:00',
        '2026-10-01T09:30:00-03:00',
        '2026-10-01T09:45:00-03:00',
        '2026-10-01T10:00:00-03:00'
      ]
    )
  end

  it 'returns only the intersection when a published booking requires multiple calendar resources' do
    card
    date = Date.new(2026, 10, 1)
    second_resource = KanbanCalendarResource.create!(
      account: account,
      name: 'Specialist',
      resource_type: 'generic',
      timezone: 'America/Sao_Paulo'
    )
    resource.kanban_calendar_availability_rules.create!(
      kind: 'weekly_window', weekday: date.wday, starts_at_local: '09:00', ends_at_local: '11:00'
    )
    second_resource.kanban_calendar_availability_rules.create!(
      kind: 'weekly_window', weekday: date.wday, starts_at_local: '09:30', ends_at_local: '11:00'
    )
    settings = integration.settings.deep_dup
    settings['calendar']['bookings']['initial_consultation']['resource_ids'] = [resource.id, second_resource.id]
    integration.update!(settings: settings)

    post '/public/api/v1/raevo_ai/calendar/availability', params: {
      conversation_id: conversation.display_id,
      board_key: 'acquisition',
      booking_key: 'initial_consultation',
      starts_on: date.iso8601,
      ends_on: date.iso8601
    }, headers: headers, as: :json

    expect(response).to have_http_status(:ok), response.body
    expect(response.parsed_body['slots']).to eq(
      [
        '2026-10-01T09:30:00-03:00',
        '2026-10-01T09:45:00-03:00',
        '2026-10-01T10:00:00-03:00'
      ]
    )
  end

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

  it 'projects one confirmed Feegow appointment idempotently as read only' do
    card
    params = {
      action_id: 'feegow-sync:630:v1',
      conversation_id: conversation.display_id,
      board_key: 'acquisition',
      booking_key: 'initial_consultation',
      provider: 'feegow',
      external_id: '630',
      starts_at: '2026-10-01T13:00:00-03:00',
      ends_at: '2026-10-01T13:50:00-03:00',
      status: 'scheduled',
      source_status: 'Agendado',
      source_updated_at: '2026-09-09T12:00:00Z',
      source_hash: 'source-v1'
    }

    expect do
      post '/public/api/v1/raevo_ai/calendar/external_appointments', params: params, headers: headers, as: :json
    end.to change(KanbanCalendarAppointment, :count).by(1)

    appointment = KanbanCalendarAppointment.last
    expect(appointment).to have_attributes(
      source_provider: 'feegow',
      source_external_id: '630',
      source_read_only: true,
      source_status: 'Agendado',
      source_hash: 'source-v1'
    )
    expect(appointment.kanban_calendar_appointment_events.last.metadata).to include(
      'provider' => 'feegow', 'operation' => 'created', 'action_id' => 'feegow-sync:630:v1'
    )

    params[:action_id] = 'feegow-sync:630:v2'
    params[:starts_at] = '2026-10-02T14:00:00-03:00'
    params[:ends_at] = '2026-10-02T14:50:00-03:00'
    params[:source_hash] = 'source-v2'
    params[:source_updated_at] = '2026-09-09T13:00:00Z'

    expect do
      post '/public/api/v1/raevo_ai/calendar/external_appointments', params: params, headers: headers, as: :json
    end.not_to change(KanbanCalendarAppointment, :count)

    expect(response).to have_http_status(:ok), response.body
    expect(appointment.reload).to have_attributes(
      starts_at: Time.iso8601('2026-10-02T14:00:00-03:00'),
      source_hash: 'source-v2'
    )
  end

  it 'does not regress a Feegow projection with an older source event' do
    card
    current = {
      action_id: 'feegow-sync:630:current', conversation_id: conversation.display_id,
      board_key: 'acquisition', booking_key: 'initial_consultation', provider: 'feegow', external_id: '630',
      starts_at: '2026-10-02T14:00:00-03:00', ends_at: '2026-10-02T14:50:00-03:00', status: 'scheduled',
      source_updated_at: '2026-09-09T13:00:00Z', source_hash: 'source-current'
    }
    post '/public/api/v1/raevo_ai/calendar/external_appointments', params: current, headers: headers, as: :json

    stale = current.merge(
      action_id: 'feegow-sync:630:stale', starts_at: '2026-10-03T15:00:00-03:00',
      ends_at: '2026-10-03T15:50:00-03:00', source_updated_at: '2026-09-09T12:30:00Z', source_hash: 'source-stale'
    )
    post '/public/api/v1/raevo_ai/calendar/external_appointments', params: stale, headers: headers, as: :json

    appointment = KanbanCalendarAppointment.last
    expect(response).to have_http_status(:ok), response.body
    expect(appointment).to have_attributes(
      starts_at: Time.iso8601('2026-10-02T14:00:00-03:00'), source_hash: 'source-current'
    )
  end
end
