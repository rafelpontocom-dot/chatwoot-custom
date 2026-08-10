require 'rails_helper'

RSpec.describe 'Calendar appointments API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account, name: 'Marina Costa') }
  let(:procedure) do
    KanbanCalendarProcedure.create!(
      account: account,
      name: 'Consulta inicial',
      duration_minutes: 50,
      recurrence_allowed: false
    )
  end
  let(:resource) do
    KanbanCalendarResource.create!(
      account: account,
      name: 'Dra. Ana',
      resource_type: 'generic',
      timezone: 'America/Sao_Paulo'
    )
  end

  it 'creates and lists account-scoped appointments' do
    post "/api/v1/accounts/#{account.id}/calendar/appointments",
         headers: administrator.create_new_auth_token,
         params: {
           appointment: {
             contact_id: contact.id,
             procedure_id: procedure.id,
             resource_ids: [resource.id],
             starts_at: '2026-08-12T13:00:00-03:00',
             timezone: 'America/Sao_Paulo'
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include(
      'status' => 'scheduled',
      'contact' => include('id' => contact.id, 'name' => 'Marina Costa')
    )

    get "/api/v1/accounts/#{account.id}/calendar/appointments",
        headers: administrator.create_new_auth_token,
        params: { starts_at: '2026-08-12T00:00:00-03:00', ends_at: '2026-08-13T00:00:00-03:00' },
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.length).to eq(1)
  end

  it 'returns a conflict for an occupied resource' do
    KanbanCalendar::BookAppointmentService.new(
      account: account,
      contact: contact,
      procedure: procedure,
      resource_ids: [resource.id],
      starts_at: Time.iso8601('2026-08-12T13:00:00-03:00'),
      timezone: 'America/Sao_Paulo'
    ).perform!

    post "/api/v1/accounts/#{account.id}/calendar/appointments",
         headers: administrator.create_new_auth_token,
         params: {
           appointment: {
             contact_id: create(:contact, account: account).id,
             procedure_id: procedure.id,
             resource_ids: [resource.id],
             starts_at: '2026-08-12T13:15:00-03:00',
             timezone: 'America/Sao_Paulo'
           }
         },
         as: :json

    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body['resource_ids']).to eq([resource.id])
  end

  it 'lists appointments linked to an opportunity without requiring a date range' do
    board = create(:kanban_board, account: account)
    board.update!(calendar_enabled: true, calendar_procedure_ids: [procedure.id])
    stage = create(:kanban_stage, account: account, kanban_board: board)
    card = create(:kanban_card, account: account, kanban_board: board, kanban_stage: stage, contact: contact)
    linked_appointment = KanbanCalendar::BookAppointmentService.new(
      account: account,
      contact: contact,
      procedure: procedure,
      resource_ids: [resource.id],
      starts_at: Time.iso8601('2026-08-12T13:00:00-03:00'),
      timezone: 'America/Sao_Paulo',
      kanban_card: card
    ).perform!

    KanbanCalendar::BookAppointmentService.new(
      account: account,
      contact: contact,
      procedure: procedure,
      resource_ids: [resource.id],
      starts_at: Time.iso8601('2026-08-13T13:00:00-03:00'),
      timezone: 'America/Sao_Paulo'
    ).perform!

    get "/api/v1/accounts/#{account.id}/calendar/appointments",
        headers: administrator.create_new_auth_token,
        params: { kanban_card_id: card.id },
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to contain_exactly(
      include(
        'id' => linked_appointment.id,
        'kanban_card_id' => card.id,
        'kanban_card' => include('id' => card.id, 'kanban_board_id' => board.id, 'subject' => card.subject)
      )
    )
  end

  it 'lists contact appointments when the calendar is opened from a contact context' do
    appointment = KanbanCalendar::BookAppointmentService.new(
      account: account,
      contact: contact,
      procedure: procedure,
      resource_ids: [resource.id],
      starts_at: Time.iso8601('2026-08-12T13:00:00-03:00'),
      timezone: 'America/Sao_Paulo'
    ).perform!

    get "/api/v1/accounts/#{account.id}/calendar/appointments",
        headers: administrator.create_new_auth_token,
        params: { contact_id: contact.id },
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.map { |payload| payload['id'] }).to include(appointment.id)
  end

  it 'searches appointments by contact details and opportunity title' do
    contact.update!(email: 'marina@example.com', phone_number: '+5511999999999')
    board = create(:kanban_board, account: account)
    board.update!(calendar_enabled: true, calendar_procedure_ids: [procedure.id])
    stage = create(:kanban_stage, account: account, kanban_board: board)
    card = create(
      :kanban_card,
      account: account,
      kanban_board: board,
      kanban_stage: stage,
      contact: contact,
      subject: 'Plano de acompanhamento Marina'
    )
    appointment = KanbanCalendar::BookAppointmentService.new(
      account: account,
      contact: contact,
      procedure: procedure,
      resource_ids: [resource.id],
      starts_at: Time.iso8601('2026-08-12T13:00:00-03:00'),
      timezone: 'America/Sao_Paulo',
      kanban_card: card
    ).perform!

    ['Marina Costa', 'marina@example.com', '999999999', 'acompanhamento'].each do |query|
      get "/api/v1/accounts/#{account.id}/calendar/appointments",
          headers: administrator.create_new_auth_token,
          params: {
            starts_at: '2026-08-12T00:00:00-03:00',
            ends_at: '2026-08-13T00:00:00-03:00',
            q: query
          },
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to contain_exactly(include('id' => appointment.id))
    end
  end

  it 'filters appointments by operational status' do
    scheduled = KanbanCalendar::BookAppointmentService.new(
      account: account,
      contact: contact,
      procedure: procedure,
      resource_ids: [resource.id],
      starts_at: Time.iso8601('2026-08-12T13:00:00-03:00'),
      timezone: 'America/Sao_Paulo'
    ).perform!
    canceled = KanbanCalendar::BookAppointmentService.new(
      account: account,
      contact: contact,
      procedure: procedure,
      resource_ids: [resource.id],
      starts_at: Time.iso8601('2026-08-12T15:00:00-03:00'),
      timezone: 'America/Sao_Paulo'
    ).perform!
    canceled.update!(status: 'canceled', canceled_at: Time.current)

    get "/api/v1/accounts/#{account.id}/calendar/appointments",
        headers: administrator.create_new_auth_token,
        params: {
          starts_at: '2026-08-12T00:00:00-03:00',
          ends_at: '2026-08-13T00:00:00-03:00',
          status: 'scheduled'
        },
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to contain_exactly(include('id' => scheduled.id))
  end

  it 'does not duplicate an appointment reserved across selected resources' do
    second_resource = KanbanCalendarResource.create!(
      account: account,
      name: 'Sala 2',
      resource_type: 'room',
      timezone: 'America/Sao_Paulo'
    )
    appointment = KanbanCalendar::BookAppointmentService.new(
      account: account,
      contact: contact,
      procedure: procedure,
      resource_ids: [resource.id, second_resource.id],
      starts_at: Time.iso8601('2026-08-12T13:00:00-03:00'),
      timezone: 'America/Sao_Paulo'
    ).perform!

    get "/api/v1/accounts/#{account.id}/calendar/appointments",
        headers: administrator.create_new_auth_token,
        params: {
          starts_at: '2026-08-12T00:00:00-03:00',
          ends_at: '2026-08-13T00:00:00-03:00',
          resource_ids: [resource.id, second_resource.id]
        },
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to contain_exactly(include('id' => appointment.id))
  end

  it 'returns a conflict when a status update uses a stale version' do
    appointment = KanbanCalendar::BookAppointmentService.new(
      account: account,
      contact: contact,
      procedure: procedure,
      resource_ids: [resource.id],
      starts_at: Time.iso8601('2026-08-12T13:00:00-03:00'),
      timezone: 'America/Sao_Paulo'
    ).perform!
    stale_lock_version = appointment.lock_version
    appointment.update!(notes: 'Atualizada por outro agente')

    patch "/api/v1/accounts/#{account.id}/calendar/appointments/#{appointment.id}",
          headers: administrator.create_new_auth_token,
          params: { appointment: { action: 'confirm', lock_version: stale_lock_version } },
          as: :json

    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body['message']).to include('changed')
  end
end
