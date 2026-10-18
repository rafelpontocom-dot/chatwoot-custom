require 'rails_helper'

RSpec.describe Raevo::HomeInsights do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:first_board) { create(:kanban_board, account: account) }
  let(:second_board) { create(:kanban_board, account: account) }

  def insights_for(user, boards: [first_board, second_board], inbox_id: nil)
    described_class.new(
      account: account, user: user, account_user: account.account_users.find_by(user: user),
      boards: boards, inbox_id: inbox_id
    )
  end

  def card(board, **attributes)
    create(:kanban_card, account: account, kanban_board: board, **attributes)
  end

  it 'keeps response time to administrators, as the Chatwoot reports do' do
    expect(insights_for(administrator).available).to include('kpi-first-response')
    expect(insights_for(agent).available).not_to include('kpi-first-response')
    expect(insights_for(agent).values(['kpi-first-response'])).to eq({})
  end

  it 'offers the AI insight only while the integration is switched on' do
    expect(insights_for(administrator).available).not_to include('kpi-ai-opportunities')
  end

  # A taxa recalcula-se das somas: a média de 100% (1 de 1) e 0% (0 de 3) seria
  # 50%, e a verdade é 1 em 4.
  it 'adds the funnels up and recomputes the close rate from the totals' do
    card(first_board, amount_cents: 10_000)
    card(second_board, amount_cents: 5_000)
    card(first_board, amount_cents: 7_000, won_at: Time.current)
    3.times { card(second_board, lost_at: Time.current, lost_reason: 'Preço') }

    values = insights_for(administrator).values(%w[kpi-pipeline-value kpi-close-rate kpi-won-month])

    expect(values['kpi-pipeline-value'][:amount_cents]).to eq(15_000)
    expect(values['kpi-close-rate']).to eq(rate: 25.0, closed: 4)
    expect(values['kpi-won-month']).to include(count: 1, amount_cents: 7_000)
  end

  it 'gives no close rate before anything closed this month' do
    expect(insights_for(administrator).values(['kpi-close-rate'])['kpi-close-rate']).to eq(rate: nil, closed: 0)
  end

  it 'averages the first response of today and of the week' do
    create(:reporting_event, account: account, name: 'first_response', value: 600, created_at: Time.current)
    create(:reporting_event, account: account, name: 'first_response', value: 1800, created_at: 3.days.ago)

    expect(insights_for(administrator).values(['kpi-first-response'])['kpi-first-response'])
      .to eq(today_seconds: 600, week_seconds: 1200)
  end

  # Cancelar com aviso não é faltar: as canceladas não entram na taxa.
  it 'counts attendance over completed and missed, leaving cancellations out' do
    summary = { completed: { current: 9 }, no_show: { current: 1 }, canceled: { current: 4 } }
    allow(KanbanCalendar::AgendaSummary).to receive(:new).and_return(instance_double(KanbanCalendar::AgendaSummary, call: summary))

    expect(insights_for(administrator).values(['kpi-attendance'])['kpi-attendance'])
      .to eq(rate: 90, no_show: 1, canceled: 4)
  end

  it 'counts conversations waiting on us for more than a day, in the chosen inbox' do
    inbox = create(:inbox, account: account)
    # Depois de criar: ao criar, a conversa põe `waiting_since` na hora de agora.
    create(:conversation, account: account, inbox: inbox, status: :open).update!(waiting_since: 2.days.ago)
    create(:conversation, account: account, inbox: inbox, status: :open).update!(waiting_since: 2.hours.ago)
    create(:conversation, account: account, status: :open).update!(waiting_since: 3.days.ago)

    expect(insights_for(administrator).values(['kpi-waiting-24h'])['kpi-waiting-24h']).to eq(count: 2)
    expect(insights_for(administrator, inbox_id: inbox.id).values(['kpi-waiting-24h'])['kpi-waiting-24h']).to eq(count: 1)
  end
end
