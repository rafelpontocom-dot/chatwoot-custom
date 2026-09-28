require 'rails_helper'

RSpec.describe 'Calendar appointments status filter', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account) }
  let(:zone) { ActiveSupport::TimeZone['America/Sao_Paulo'] }
  let(:procedure) do
    KanbanCalendarProcedure.create!(account: account, name: 'Consulta', duration_minutes: 50, recurrence_allowed: false)
  end
  let(:resource) do
    KanbanCalendarResource.create!(
      account: account, name: 'Dra. Anna', resource_type: 'generic', timezone: 'America/Sao_Paulo'
    )
  end

  def marcar(starts_at, status: nil)
    appointment = KanbanCalendar::BookAppointmentService.new(
      account: account, contact: contact, procedure: procedure, resource_ids: [resource.id],
      starts_at: starts_at, timezone: 'America/Sao_Paulo', actor: nil
    ).perform!
    appointment.update!(status: status) if status
    appointment
  end

  def listar(status)
    get "/api/v1/accounts/#{account.id}/calendar/appointments", params: {
      starts_at: zone.parse('2026-10-05 00:00').iso8601,
      ends_at: zone.parse('2026-10-06 00:00').iso8601,
      status: status
    }, headers: administrator.create_new_auth_token, as: :json
    response.parsed_body
  end

  # O indicador «Marcações hoje» conta o que está de pé. Sem este recorte o
  # número contava um conjunto e o clique levava a outro: num dia só de
  # canceladas, a grade mostrava duas e o indicador dizia zero.
  it 'answers the still-standing set for `active`, not a single status' do
    de_pe = marcar(zone.parse('2026-10-05 14:00'))
    marcar(zone.parse('2026-10-05 16:00'), status: 'canceled')
    marcar(zone.parse('2026-10-05 17:00'), status: 'no_show')

    corpo = listar('active')

    expect(corpo.pluck('id')).to contain_exactly(de_pe.id)
  end

  it 'still filters by one status when one is asked for' do
    marcar(zone.parse('2026-10-05 14:00'))
    cancelada = marcar(zone.parse('2026-10-05 16:00'), status: 'canceled')

    expect(listar('canceled').pluck('id')).to contain_exactly(cancelada.id)
  end
end
