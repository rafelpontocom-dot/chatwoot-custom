require 'rails_helper'

RSpec.describe KanbanCalendar::PublicBookingService do
  let(:account) { create(:account) }
  let(:board) { create(:kanban_board, account: account) }
  let(:stage) { create(:kanban_stage, account: account, kanban_board: board) }
  let(:inbox) { create(:inbox, account: account) }
  let(:page) do
    KanbanCalendarBookingPage.create!(
      account: account,
      active: true,
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
      public_slug: 'consulta-inicial'
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
  let(:starts_at) { Time.zone.parse('2026-08-17 13:00:00') }

  before do
    board.update!(calendar_enabled: true, calendar_procedure_ids: [procedure.id])
    resource.kanban_calendar_availability_rules.create!(
      kind: 'weekly_window',
      weekday: starts_at.wday,
      starts_at_local: '09:00',
      ends_at_local: '18:00'
    )
  end

  it 'creates a contact, opportunity and auditable booking from a public form' do
    appointment = described_class.new(
      booking_page: page,
      procedure: procedure,
      booking: {
        contact_attributes: {
          name: 'Pedro Raevo',
          email: 'pedro@example.com',
          phone_number: '+5511999999999'
        },
        resource_ids: [resource.id],
        starts_at: starts_at,
        timezone: 'America/Sao_Paulo'
      }
    ).perform!

    expect(appointment.contact).to have_attributes(name: 'Pedro Raevo', email: 'pedro@example.com')
    expect(appointment.kanban_card).to have_attributes(kanban_board: board, kanban_stage: stage, inbox: inbox)
    expect(appointment.external_refs).to include('source' => 'public_booking', 'booking_page_id' => page.id)
  end
end
