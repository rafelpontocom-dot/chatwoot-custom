require 'rails_helper'

RSpec.describe KanbanCalendar::ProcedureLimits do
  let(:account) { create(:account) }
  let(:procedure) { KanbanCalendarProcedure.create!(account: account, name: 'Retorno', duration_minutes: 30) }
  let(:agenda) { KanbanCalendarResource.create!(account: account, name: 'Sala 1', resource_type: 'room', timezone: 'America/Sao_Paulo') }

  it 'lets the procedure win over the agenda and the agenda over the account page' do
    create_page(slot_interval_minutes: 20, minimum_notice_minutes: 120)
    agenda.update!(slot_interval_minutes: 30)

    expect(described_class.new(procedure: procedure, resource: agenda).slot_interval_minutes).to eq(30)
    expect(described_class.new(procedure: procedure).minimum_notice_minutes).to eq(120)

    procedure.update!(slot_interval_minutes: 60, minimum_notice_minutes: 1440)

    expect(described_class.new(procedure: procedure, resource: agenda).slot_interval_minutes).to eq(60)
    expect(described_class.new(procedure: procedure).minimum_notice_minutes).to eq(1440)
  end

  it 'falls back to the code defaults when nothing was configured' do
    limits = described_class.new(procedure: procedure)

    expect([limits.slot_interval_minutes, limits.minimum_notice_minutes, limits.maximum_notice_days]).to eq([15, 0, 60])
  end

  def create_page(**attributes)
    KanbanCalendarBookingPage.create!(account: account, **attributes)
  end
end
