require 'rails_helper'

RSpec.describe KanbanCalendar::AgendaSummary do
  let(:account) { create(:account) }
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

  before { account.update!(settings: account.settings.merge('reporting_timezone' => 'America/Sao_Paulo')) }

  def marcar(starts_at)
    KanbanCalendar::BookAppointmentService.new(
      account: account, contact: contact, procedure: procedure, resource_ids: [resource.id],
      starts_at: starts_at, timezone: 'America/Sao_Paulo', actor: nil
    ).perform!
  end

  def bloquear(starts_at, external_event_id)
    KanbanCalendarExternalBusyBlock.create!(
      account: account, kanban_calendar_resource: resource, provider: 'google_calendar',
      external_event_id: external_event_id, starts_at: starts_at, ends_at: starts_at + 1.hour
    )
  end

  # O dia com cinco blocos e nenhuma marcação lia-se «Marcações hoje 0»: o número
  # conta consultas, a grade mostra também o que vem de fora. Sem esta contagem o
  # zero fica certo e ilegível ao mesmo tempo.
  it 'counts the blocks imported from another calendar apart from the appointments' do
    travel_to zone.parse('2026-10-05 09:00') do
      marcar(zone.parse('2026-10-05 14:00'))
      bloquear(zone.parse('2026-10-05 08:00'), 'g-1')
      bloquear(zone.parse('2026-10-05 11:00'), 'g-2')
      bloquear(zone.parse('2026-10-06 08:00'), 'g-3')

      hoje = described_class.new(account: account).call[:today]

      expect(hoje[:count]).to eq(1)
      expect(hoje[:busy_blocks]).to eq(2)
    end
  end

  it 'does not count another account blocks as this one busy day' do
    outra = create(:account)
    outro_recurso = KanbanCalendarResource.create!(
      account: outra, name: 'Sala', resource_type: 'room', timezone: 'America/Sao_Paulo'
    )

    travel_to zone.parse('2026-10-05 09:00') do
      KanbanCalendarExternalBusyBlock.create!(
        account: outra, kanban_calendar_resource: outro_recurso, provider: 'google_calendar',
        external_event_id: 'x-1', starts_at: zone.parse('2026-10-05 08:00'), ends_at: zone.parse('2026-10-05 09:00')
      )

      expect(described_class.new(account: account).call[:today][:busy_blocks]).to eq(0)
    end
  end

  it 'leaves a canceled appointment out of the day that is still standing' do
    travel_to zone.parse('2026-10-05 09:00') do
      marcar(zone.parse('2026-10-05 14:00')).update!(status: 'canceled')

      expect(described_class.new(account: account).call[:today][:count]).to eq(0)
    end
  end
end
