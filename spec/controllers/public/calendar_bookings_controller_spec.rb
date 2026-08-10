require 'rails_helper'

RSpec.describe 'Public calendar booking API', type: :request do
  let(:account) { create(:account) }
  let(:board) { create(:kanban_board, account: account) }
  let(:stage) { create(:kanban_stage, account: account, kanban_board: board) }
  let(:inbox) { create(:inbox, account: account) }
  let(:page) do
    KanbanCalendarBookingPage.create!(
      account: account,
      active: true,
      title: 'Agenda Raevo',
      kanban_board: board,
      kanban_stage: stage,
      inbox: inbox
    )
  end
  let(:procedure) do
    KanbanCalendarProcedure.create!(
      account: account,
      name: 'Consulta inicial',
      duration_minutes: 50,
      public_booking_enabled: true,
      public_slug: 'consulta-inicial',
      public_title: 'Primeira consulta'
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

  before do
    board.update!(calendar_enabled: true, calendar_procedure_ids: [procedure.id])
    resource.kanban_calendar_availability_rules.create!(
      kind: 'weekly_window',
      weekday: 0,
      starts_at_local: '09:00',
      ends_at_local: '18:00'
    )
  end

  it 'shows only published procedures for the public booking page' do
    account.update!(locale: :pt)

    get "/agendar/#{page.public_token}", as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'title' => 'Agenda Raevo',
      'locale' => 'pt',
      'procedures' => [include('slug' => 'consulta-inicial', 'title' => 'Primeira consulta')]
    )
  end

  it 'renders the public booking shell for a valid page' do
    get "/agendar/#{page.public_token}"

    expect(response).to have_http_status(:success)
    expect(response.body).to include('id="public-booking-app"')
  end

  it 'creates an appointment from the public procedure page' do
    post "/agendar/#{page.public_token}/consulta-inicial/reservas",
         params: {
           booking: {
             name: 'Pedro Raevo',
             email: 'pedro@example.com',
             phone_number: '+5511999999999',
             resource_ids: [resource.id],
             starts_at: '2026-08-16T13:00:00-03:00',
             timezone: 'America/Sao_Paulo',
             consent: true
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include('status' => 'scheduled')
    expect(KanbanCalendarAppointment.last.external_refs).to include('source' => 'public_booking')
  end

  it 'limits repeated public booking attempts from the same address' do
    allow(Rails.cache).to receive(:increment).and_return(11)

    post "/agendar/#{page.public_token}/consulta-inicial/reservas",
         params: { booking: { name: 'Pedro', email: 'pedro@example.com', consent: true } },
         as: :json

    expect(response).to have_http_status(:too_many_requests)
  end

  it 'returns the selected procedure for an available private invitation' do
    invitation = KanbanCalendarBookingLink.create!(
      account: account,
      kanban_calendar_booking_page: page,
      kanban_calendar_procedure: procedure,
      max_uses: 1
    )

    get "/agendar/convite/#{invitation.token}", as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'procedure' => include('slug' => 'consulta-inicial', 'resources' => [include('id' => resource.id)])
    )
  end

  it 'books through a private invitation and consumes it after the reservation' do
    invitation = KanbanCalendarBookingLink.create!(
      account: account,
      kanban_calendar_booking_page: page,
      kanban_calendar_procedure: procedure,
      max_uses: 1
    )

    post "/agendar/convite/#{invitation.token}/consulta-inicial/reservas",
         params: {
           booking: {
             name: 'Pedro Raevo',
             email: 'pedro@example.com',
             phone_number: '+5511999999999',
             resource_ids: [resource.id],
             starts_at: '2026-08-16T13:00:00-03:00',
             timezone: 'America/Sao_Paulo',
             consent: true
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    expect(invitation.reload.uses_count).to eq(1)
    expect(invitation).not_to be_available
  end

  it 'allows a private invitation without a fixed procedure to choose a published procedure' do
    invitation = KanbanCalendarBookingLink.create!(
      account: account,
      kanban_calendar_booking_page: page
    )

    get "/agendar/convite/#{invitation.token}/consulta-inicial", as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('slug' => 'consulta-inicial')

    post "/agendar/convite/#{invitation.token}/consulta-inicial/reservas",
         params: {
           booking: {
             name: 'Pedro Raevo',
             email: 'pedro@example.com',
             resource_ids: [resource.id],
             starts_at: '2026-08-16T13:00:00-03:00',
             timezone: 'America/Sao_Paulo',
             consent: true
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    expect(invitation.reload.uses_count).to eq(1)
  end
end
