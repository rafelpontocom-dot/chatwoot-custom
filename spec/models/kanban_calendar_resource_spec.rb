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
end
