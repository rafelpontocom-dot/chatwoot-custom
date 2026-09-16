require 'rails_helper'

RSpec.describe KanbanCalendar::FeegowImportService do
  let(:account) { create(:account) }
  let(:connection) do
    KanbanCalendarFeegowConnection.create!(
      account: account, api_token: 'token', status: 'connected', token_expires_at: 80.days.from_now
    )
  end
  let(:client) { instance_double(KanbanCalendar::FeegowClient) }
  let(:now) { Time.zone.parse('2026-09-16 09:00:00') }

  def agenda(name, feegow_settings)
    KanbanCalendarResource.create!(
      account: account, name: name, resource_type: 'user', timezone: 'America/Sao_Paulo',
      settings: feegow_settings ? { 'feegow' => feegow_settings } : {}
    )
  end

  def consulta(id, data, horario, extra = {})
    { 'agendamento_id' => id, 'data' => data, 'horario' => horario, 'duracao' => 30 }.merge(extra)
  end

  def import(appointments_by_professional)
    allow(client).to receive(:appointments) do |professional_id:, **|
      appointments_by_professional.fetch(professional_id, [])
    end
    described_class.new(connection: connection, client: client, now: now).perform!
  end

  it 'turns the Feegow agenda of a mapped professional into busy blocks' do
    resource = agenda('Dra. Anna', { 'professional_id' => 9 })

    import(9 => [consulta(500, '17-09-2026', '14:00')])

    expect(resource.kanban_calendar_external_busy_blocks.sole).to have_attributes(
      provider: 'feegow',
      external_event_id: '500',
      starts_at: Time.zone.parse('2026-09-17 17:00:00'),
      ends_at: Time.zone.parse('2026-09-17 17:30:00')
    )
    expect(connection.reload.last_imported_at).to be_present
  end

  it 'leaves alone an agenda that was never mapped to Feegow' do
    resource = agenda('Sala 1', nil)

    import(9 => [consulta(500, '17-09-2026', '14:00')])

    expect(resource.kanban_calendar_external_busy_blocks).to be_empty
    expect(client).not_to have_received(:appointments)
  end

  # Consulta cancelada devolve o horário; mantê-la bloqueada esconderia vaga.
  it 'ignores cancelled appointments' do
    resource = agenda('Dra. Anna', { 'professional_id' => 9 })

    import(9 => [consulta(501, '17-09-2026', '15:00', 'status' => 'Cancelado')])

    expect(resource.kanban_calendar_external_busy_blocks).to be_empty
  end

  it 'moves a rescheduled appointment and drops what is no longer in Feegow' do
    resource = agenda('Dra. Anna', { 'professional_id' => 9 })
    import(9 => [consulta(500, '17-09-2026', '14:00'), consulta(502, '18-09-2026', '09:00')])

    import(9 => [consulta(500, '17-09-2026', '16:00')])

    expect(resource.kanban_calendar_external_busy_blocks.pluck(:external_event_id, :starts_at)).to eq(
      [['500', Time.zone.parse('2026-09-17 19:00:00')]]
    )
  end

  it 'keeps the blocks of each agenda apart' do
    anna = agenda('Dra. Anna', { 'professional_id' => 9 })
    bruno = agenda('Dr. Bruno', { 'professional_id' => 12 })

    import(9 => [consulta(500, '17-09-2026', '14:00')], 12 => [consulta(600, '17-09-2026', '14:00')])

    expect(anna.kanban_calendar_external_busy_blocks.pluck(:external_event_id)).to eq(['500'])
    expect(bruno.kanban_calendar_external_busy_blocks.pluck(:external_event_id)).to eq(['600'])
  end

  it 'records the Feegow reason on the connection so the settings can show it' do
    agenda('Dra. Anna', { 'professional_id' => 9 })
    allow(client).to receive(:appointments).and_raise(KanbanCalendar::FeegowApiError, 'Token inválido')

    expect { described_class.new(connection: connection, client: client, now: now).perform! }
      .to raise_error(KanbanCalendar::FeegowApiError)
    expect(connection.reload).to have_attributes(status: 'error', last_error: 'Token inválido')
  end
end
