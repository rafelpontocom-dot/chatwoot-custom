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
    expect(response.parsed_body).to contain_exactly(include('id' => linked_appointment.id, 'kanban_card_id' => card.id))
  end
end
