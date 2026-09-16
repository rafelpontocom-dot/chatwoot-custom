require 'rails_helper'

RSpec.describe KanbanCalendarResource do
  let(:account) { create(:account) }

  # Quem atende na clínica não é necessariamente quem usa o CRM: um médico pode
  # não ter login nenhum. Exigir utilizador obrigava a criar contas só para
  # poder pôr alguém na agenda.
  it 'accepts a professional who does not use the CRM' do
    resource = described_class.new(
      account: account,
      name: 'Dra. Ana',
      resource_type: 'user',
      timezone: 'America/Sao_Paulo'
    )

    expect(resource).to be_valid
  end

  it 'still links a professional to a CRM user when one is chosen' do
    user = create(:user, account: account)
    resource = described_class.new(
      account: account,
      name: 'Dr. Bruno',
      resource_type: 'user',
      user: user,
      timezone: 'America/Sao_Paulo'
    )

    expect(resource).to be_valid
  end

  it 'refuses a CRM user from another account' do
    resource = described_class.new(
      account: account,
      name: 'Dr. Bruno',
      resource_type: 'user',
      user: create(:user, account: create(:account)),
      timezone: 'America/Sao_Paulo'
    )

    expect(resource).not_to be_valid
    expect(resource.errors[:user]).to be_present
  end

  it 'accepts a room with one appointment capacity' do
    resource = described_class.new(
      account: account,
      name: 'Consultório 1',
      resource_type: 'room',
      timezone: 'America/Sao_Paulo',
      capacity: 1
    )

    expect(resource).to be_valid
  end

  # Agenda nova nascia sem janela de trabalho nenhuma, e a tela de marcação não
  # oferecia horário nenhum sem dizer porquê — foi o que o Alysson viu.
  it 'starts a new agenda with a weekday working window that can be edited' do
    resource = described_class.create!(account: account, name: 'Dra. Ana', resource_type: 'user', timezone: 'America/Sao_Paulo')

    rules = resource.kanban_calendar_availability_rules.pluck(:kind, :weekday, :starts_at_local, :ends_at_local)

    expect(rules.map { |kind, weekday, starts_at, ends_at| [kind, weekday, starts_at.strftime('%H:%M'), ends_at.strftime('%H:%M')] })
      .to eq((1..5).map { |weekday| ['weekly_window', weekday, '08:00', '18:00'] })
  end

  it 'keeps the hours an agenda was created with, instead of adding the default ones' do
    resource = described_class.new(account: account, name: 'Sala 1', resource_type: 'room', timezone: 'America/Sao_Paulo')
    resource.kanban_calendar_availability_rules.build(kind: 'weekly_window', weekday: 6, starts_at_local: '09:00', ends_at_local: '13:00')
    resource.save!

    expect(resource.kanban_calendar_availability_rules.pluck(:weekday)).to eq([6])
  end

  it 'only accepts a slot interval the agenda can actually offer' do
    resource = described_class.new(account: account, name: 'Sala 2', resource_type: 'room', timezone: 'America/Sao_Paulo')

    expect(resource.tap { |r| r.slot_interval_minutes = 30 }).to be_valid
    expect(resource.tap { |r| r.slot_interval_minutes = nil }).to be_valid
    expect(resource.tap { |r| r.slot_interval_minutes = 7 }).not_to be_valid
  end
end
