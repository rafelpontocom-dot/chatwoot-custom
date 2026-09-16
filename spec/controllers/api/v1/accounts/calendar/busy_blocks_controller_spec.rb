require 'rails_helper'

RSpec.describe 'Calendar busy blocks API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:resource) { KanbanCalendarResource.create!(account: account, name: 'Dra. Ana', resource_type: 'user', timezone: 'America/Sao_Paulo') }
  let(:other_resource) { KanbanCalendarResource.create!(account: account, name: 'Sala 1', resource_type: 'room', timezone: 'America/Sao_Paulo') }

  def block(for_resource, event_id, starts_at, provider = 'google_calendar')
    KanbanCalendarExternalBusyBlock.create!(
      account: account, kanban_calendar_resource: for_resource, provider: provider,
      external_event_id: event_id, starts_at: starts_at, ends_at: starts_at + 1.hour
    )
  end

  it 'lists the Google busy times in the visible range, without event details' do
    inside = block(resource, 'dentista', Time.zone.parse('2026-09-16 13:00:00'))
    block(resource, 'fora', Time.zone.parse('2026-10-20 13:00:00'))

    get "/api/v1/accounts/#{account.id}/calendar/busy_blocks",
        params: { starts_at: '2026-09-14T00:00:00Z', ends_at: '2026-09-21T00:00:00Z' },
        headers: agent.create_new_auth_token

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq([{
                                         'id' => inside.id,
                                         'resource_id' => resource.id,
                                         'starts_at' => inside.starts_at.iso8601,
                                         'ends_at' => inside.ends_at.iso8601,
                                         'all_day' => false,
                                         'source' => 'google_calendar'
                                       }])
  end

  it 'keeps only the agendas that are visible on screen' do
    block(resource, 'dentista', Time.zone.parse('2026-09-16 13:00:00'))
    sala = block(other_resource, 'manutencao', Time.zone.parse('2026-09-16 15:00:00'))

    get "/api/v1/accounts/#{account.id}/calendar/busy_blocks",
        params: { starts_at: '2026-09-14T00:00:00Z', ends_at: '2026-09-21T00:00:00Z', resource_ids: [other_resource.id] },
        headers: agent.create_new_auth_token

    expect(response.parsed_body.pluck('id')).to eq([sala.id])
  end

  it 'does not show busy times of another account' do
    other_account = create(:account)
    other = KanbanCalendarResource.create!(account: other_account, name: 'Outro', resource_type: 'user', timezone: 'America/Sao_Paulo')
    KanbanCalendarExternalBusyBlock.create!(
      account: other_account, kanban_calendar_resource: other, provider: 'google_calendar',
      external_event_id: 'x', starts_at: Time.zone.parse('2026-09-16 13:00:00'), ends_at: Time.zone.parse('2026-09-16 14:00:00')
    )

    get "/api/v1/accounts/#{account.id}/calendar/busy_blocks",
        params: { starts_at: '2026-09-14T00:00:00Z', ends_at: '2026-09-21T00:00:00Z' },
        headers: agent.create_new_auth_token

    expect(response.parsed_body).to eq([])
  end

  # Google e Feegow ocupam o mesmo horário da mesma agenda; a tela precisa de
  # saber de quem é cada bloco para o dizer a quem lê.
  it 'says which provider each busy time came from' do
    block(resource, 'dentista', Time.zone.parse('2026-09-16 13:00:00'))
    block(resource, '7001', Time.zone.parse('2026-09-16 15:00:00'), 'feegow')

    get "/api/v1/accounts/#{account.id}/calendar/busy_blocks",
        params: { starts_at: '2026-09-14T00:00:00Z', ends_at: '2026-09-21T00:00:00Z' },
        headers: agent.create_new_auth_token

    expect(response.parsed_body.pluck('source')).to eq(%w[google_calendar feegow])
  end
end
