require 'rails_helper'

RSpec.describe KanbanCalendar::FeegowClient do
  let(:account) { create(:account) }
  let(:connection) do
    KanbanCalendarFeegowConnection.create!(
      account: account, api_url: 'https://api.feegow.test/v1/api', api_token: 'token-da-clinica',
      status: 'connected', token_expires_at: 80.days.from_now
    )
  end
  let(:client) { described_class.new(connection: connection) }
  let(:search_url) { 'https://api.feegow.test/v1/api/appoints/search' }

  it 'reads the appointments of a professional in the window, page by page' do
    stub_request(:get, search_url)
      .with(query: hash_including('profissional_id' => '9', 'data_start' => '14-09-2026', 'data_end' => '14-03-2027'),
            headers: { 'x-access-token' => 'token-da-clinica' })
      .to_return(
        # Página cheia significa que pode haver mais: é o que faz pedir a seguinte.
        { status: 200, body: { success: true, content: Array.new(100) { |index| { agendamento_id: index + 1 } } }.to_json },
        { status: 200, body: { success: true, content: [{ agendamento_id: 101 }] }.to_json }
      )

    appointments = client.appointments(professional_id: 9, from: Date.new(2026, 9, 14), to: Date.new(2027, 3, 14))

    expect(appointments.length).to eq(101)
    expect(appointments.last['agendamento_id']).to eq(101)
    expect(a_request(:get, search_url).with(query: hash_including('start' => '100'))).to have_been_made.once
  end

  it 'lists the professionals so an agenda can be mapped to one' do
    stub_request(:get, 'https://api.feegow.test/v1/api/professional/list')
      .to_return(status: 200, body: { success: true, content: [{ profissional_id: 9, nome: 'Dra. Anna' }] }.to_json)

    expect(client.professionals).to eq([{ 'profissional_id' => 9, 'nome' => 'Dra. Anna' }])
  end

  # O token do Feegow vence a cada 90 dias; recusado é o caso mais provável de erro.
  it 'raises with the Feegow reason when the token is refused' do
    stub_request(:get, 'https://api.feegow.test/v1/api/professional/list')
      .to_return(status: 401, body: { success: false, message: 'Token inválido' }.to_json)

    expect { client.professionals }.to raise_error(KanbanCalendar::FeegowApiError, /Token inválido/)
  end

  it 'refuses to call Feegow without a token instead of asking anonymously' do
    connection.update!(status: 'disconnected', api_token: nil)

    expect { client.professionals }.to raise_error(KanbanCalendar::FeegowApiError, /token/i)
  end
end
