require 'rails_helper'

RSpec.describe 'Public calendar booking in three steps', type: :request do
  let(:account) { create(:account) }
  let(:board) { create(:kanban_board, account: account) }
  let(:stage) { create(:kanban_stage, account: account, kanban_board: board) }
  let(:inbox) { create(:inbox, account: account) }
  let(:timezone) { 'America/Sao_Paulo' }
  let(:page) do
    KanbanCalendarBookingPage.create!(account: account, active: true, kanban_board: board, kanban_stage: stage, inbox: inbox,
                                      clinic_name: 'Clínica Vida', clinic_address: 'Rua das Acácias, 120 · Recife',
                                      minimum_notice_minutes: 0)
  end
  let(:anna) { KanbanCalendarResource.create!(account: account, name: 'Dra. Anna Alice', resource_type: 'user', timezone: timezone) }
  let(:sala) { KanbanCalendarResource.create!(account: account, name: 'Sala 1', resource_type: 'room', timezone: timezone) }
  let(:procedure) do
    KanbanCalendarProcedure.create!(account: account, name: 'Avaliação com laser CO2', duration_minutes: 50, slot_interval_minutes: 60,
                                    public_booking_enabled: true, public_slug: 'avaliacao-laser', kanban_calendar_resources: [anna, sala])
  end
  let(:base) { "/agendar/#{page.public_token}/avaliacao-laser" }
  let(:wednesday) { Date.new(2026, 9, 23) }
  let(:nine) { ActiveSupport::TimeZone[timezone].local(2026, 9, 23, 9) }
  let(:patient) do
    { name: 'Marina Costa', phone_number: '+5581988771200', email: 'marina@example.com', timezone: 'America/Recife',
      notes: 'Pele sensível', consent: true }
  end

  around { |example| travel_to(ActiveSupport::TimeZone[timezone].local(2026, 9, 16, 8)) { example.run } }

  before do
    board.update!(calendar_enabled: true, calendar_procedure_ids: [procedure.id])
    [anna, sala].each do |resource|
      resource.kanban_calendar_availability_rules.delete_all
      resource.kanban_calendar_availability_rules.create!(kind: 'weekly_window', weekday: 3, starts_at_local: '09:00', ends_at_local: '12:00')
    end
  end

  def hold!(starts_at = nine)
    post "#{base}/vaga", params: { starts_at: starts_at.iso8601, timezone: 'America/Recife' }, as: :json
    response.parsed_body
  end

  it 'lights only the days with room in the month and lists the times with who attends' do
    get "#{base}/disponibilidade", params: { month: '2026-09' }, as: :json
    expect(response.parsed_body['days']).to eq(%w[2026-09-16 2026-09-23 2026-09-30])

    get "#{base}/disponibilidade", params: { date: wednesday.iso8601 }, as: :json
    expect(response.parsed_body['slots'].first).to include(
      'starts_at' => nine.utc.iso8601, 'resources' => [include('name' => 'Dra. Anna Alice'), include('name' => 'Sala 1')]
    )
  end

  it 'holds the time for another visitor and gives it back when confirmed as an appointment' do
    held = hold!
    expect(response).to have_http_status(:created)

    get "#{base}/disponibilidade", params: { date: wednesday.iso8601 }, as: :json
    expect(response.parsed_body['slots'].pluck('starts_at')).not_to include(nine.utc.iso8601)

    post "#{base}/vaga/#{held['token']}/confirmar", params: { booking: patient }, as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include('status' => 'confirmed', 'timezone' => 'America/Recife')
    appointment = KanbanCalendarAppointment.find_by!(hold_token: response.parsed_body['token'])
    expect(appointment.kanban_calendar_resources).to contain_exactly(anna, sala)
    expect(appointment.notes).to eq('Pele sensível')
    expect(KanbanCalendarSlotHold.count).to eq(0)
  end

  it 'refuses a second hold on a time someone is already filling in' do
    hold!
    hold!

    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body['code']).to eq('slot_taken')
  end

  it 'tells the page the held time expired instead of booking it' do
    held = hold!
    travel 11.minutes

    post "#{base}/vaga/#{held['token']}/confirmar", params: { booking: patient }, as: :json

    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body['code']).to eq('hold_expired')
    expect(KanbanCalendarAppointment.count).to eq(0)
  end

  context 'with online payment' do
    before do
      account.create_finance_module_setting!(enabled: true, market: 'BR', default_payment_provider: 'asaas')
      FinanceProviderConnection.create!(account: account, provider: 'asaas', environment: 'sandbox', api_key: 'key', status: 'connected')
      procedure.update!(payment_enabled: true, price_cents: 25_000, payment_methods: %w[pix card on_site])
      stub_request(:post, 'https://api-sandbox.asaas.com/v3/customers').to_return(status: 200, body: { id: 'cus_1' }.to_json)
      stub_request(:post, 'https://api-sandbox.asaas.com/v3/payments')
        .to_return(status: 200, body: { id: 'pay_1', status: 'PENDING', invoiceUrl: 'https://pay.example/1' }.to_json)
    end

    it 'waits for the provider webhook before the appointment counts as confirmed' do
      held = hold!
      post "#{base}/vaga/#{held['token']}/confirmar", params: { booking: patient.merge(payment_method: 'pix', cpf: '123.456.789-09') },
                                                      as: :json

      body = response.parsed_body
      expect(body['status']).to eq('awaiting_payment')
      expect(body['payment']).to include('amount_cents' => 25_000, 'invoice_url' => 'https://pay.example/1', 'method' => 'pix')

      payment = FinancePayment.last
      KanbanCalendarPaymentListener.instance.finance_payment_received(Events::Base.new('finance.payment.received', Time.current,
                                                                                       payment_id: payment.id))
      KanbanCalendarPaymentListener.instance.finance_payment_received(Events::Base.new('finance.payment.received', Time.current,
                                                                                       payment_id: payment.id))

      get "/agendar/reserva/#{body['token']}", as: :json
      expect(response.parsed_body['status']).to eq('confirmed')
    end

    it 'cancels the unpaid appointment and gives the time back when the hold runs out' do
      held = hold!
      post "#{base}/vaga/#{held['token']}/confirmar", params: { booking: patient.merge(payment_method: 'card', cpf: '12345678909') },
                                                      as: :json
      travel 11.minutes

      KanbanCalendar::ExpireHoldsJob.perform_now

      expect(KanbanCalendarAppointment.last.status).to eq('canceled')
      get "#{base}/disponibilidade", params: { date: wednesday.iso8601 }, as: :json
      expect(response.parsed_body['slots'].pluck('starts_at')).to include(nine.utc.iso8601)
    end

    it 'confirms at once when the patient pays at the clinic' do
      held = hold!
      post "#{base}/vaga/#{held['token']}/confirmar", params: { booking: patient.merge(payment_method: 'on_site') }, as: :json

      expect(response.parsed_body['status']).to eq('confirmed')
      expect(FinancePayment.count).to eq(0)
    end
  end

  describe 'the patient appointment link' do
    let(:token) do
      held = hold!
      post "#{base}/vaga/#{held['token']}/confirmar", params: { booking: patient }, as: :json
      response.parsed_body['token']
    end

    it 'gives an .ics with the appointment' do
      get "/agendar/reserva/#{token}/calendario"

      expect(response.media_type).to eq('text/calendar')
      expect(response.body).to include('DTSTART:20260923T120000Z', 'SUMMARY:Avaliação com laser CO2 · Clínica Vida')
    end

    it 'reschedules to a newly held time within the deadline' do
      get "/agendar/reserva/#{token}/disponibilidade", params: { date: wednesday.iso8601 }, as: :json
      eleven = response.parsed_body['slots'].last['starts_at']

      post "/agendar/reserva/#{token}/vaga", params: { starts_at: eleven }, as: :json
      post "/agendar/reserva/#{token}/remarcar", params: { hold_token: response.parsed_body['token'] }, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['starts_at']).to eq(eleven)
    end

    it 'cancels with a reason, moves the opportunity, and refuses after the deadline' do
      lost = create(:kanban_stage, account: account, kanban_board: board, category: 'lost')
      procedure.update!(on_cancel_stage_action: 'mark_lost')

      post "/agendar/reserva/#{token}/cancelar", params: { reason: '' }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)

      post "/agendar/reserva/#{token}/cancelar", params: { reason: 'Viagem' }, as: :json
      expect(response.parsed_body['status']).to eq('canceled')
      expect(KanbanCalendarAppointment.find_by!(hold_token: token).kanban_card.kanban_stage).to eq(lost)
    end

    it 'does not let the patient change it inside the deadline' do
      travel_to(nine - 2.hours)

      get "/agendar/reserva/#{token}", as: :json

      expect(response.parsed_body).to include('can_reschedule' => false, 'can_cancel' => false)
    end
  end
end
