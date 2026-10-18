# Os insights que se acrescentam ao Início editável pelo «+» (entrega 2, 18/10).
#
# Só os que já têm dados no Raevo — nenhum pede tabela nova nem chamada à ponte
# da IA. E só se calculam a pedido: o Início pede os que a pessoa pôs no seu
# arranjo, e quem não os usa não paga as consultas em cada abertura.
#
# `available` diz quais a pessoa pode acrescentar; `values(keys)` calcula os
# pedidos. Um insight que a pessoa não pode ver não está em `available` e não é
# calculado, mesmo que o peça.
class Raevo::HomeInsights
  KEYS = %w[
    kpi-pipeline-value kpi-close-rate kpi-won-month kpi-first-response
    kpi-attendance kpi-ai-opportunities kpi-waiting-24h
  ].freeze
  AI_WINDOW_DAYS = 30
  WAITING_LIMIT = 24.hours

  def initialize(account:, user:, account_user:, boards:, inbox_id: nil)
    @account = account
    @user = user
    @account_user = account_user
    @boards = boards
    @inbox_id = inbox_id
  end

  # Tempo de 1.ª resposta é relatório: o Chatwoot só os mostra a administradores,
  # e o Início não abre essa porta. A IA só existe com a integração ligada.
  def available
    KEYS.select do |key|
      case key
      when 'kpi-first-response' then administrator?
      when 'kpi-ai-opportunities' then ai_integration.present?
      else true
      end
    end
  end

  def values(keys)
    (keys & available).index_with { |key| send(METHODS.fetch(key)) }
  end

  METHODS = {
    'kpi-pipeline-value' => :pipeline_value, 'kpi-close-rate' => :close_rate, 'kpi-won-month' => :won_month,
    'kpi-first-response' => :first_response, 'kpi-attendance' => :attendance,
    'kpi-ai-opportunities' => :ai_opportunities, 'kpi-waiting-24h' => :waiting_24h
  }.freeze

  private

  attr_reader :account, :user, :boards, :inbox_id

  def administrator?
    @account_user&.administrator? || false
  end

  def ai_integration
    return @ai_integration if defined?(@ai_integration)

    integration = account.raevo_ai_integration
    @ai_integration = integration&.enabled? ? integration : nil
  end

  # O resumo comercial é por funil. Sem funil escolhido, somam-se os funis que a
  # pessoa vê — valor, ganhas e fechadas somam-se; a taxa recalcula-se das somas,
  # nunca da média das taxas, que pesaria igual um funil de 2 e um de 200.
  def commercial
    @commercial ||= boards.map { |board| KanbanBoards::CommercialSummary.new(board: board).call }
  end

  def currency
    account.currency.presence || commercial.first&.dig(:currency) || 'BRL'
  end

  def pipeline_value
    { amount_cents: commercial.sum { |summary| summary[:pipeline_value][:current] }, currency: currency }
  end

  def close_rate
    closed = commercial.sum { |summary| summary[:close_rate][:closed] }
    won = commercial.sum { |summary| summary[:won][:current][:count] }
    { rate: closed.zero? ? nil : (won.to_f / closed * 100).round(1), closed: closed }
  end

  def won_month
    {
      count: commercial.sum { |summary| summary[:won][:current][:count] },
      amount_cents: commercial.sum { |summary| summary[:won][:current][:amount_cents] },
      currency: currency
    }
  end

  def zone
    ActiveSupport::TimeZone[account.reporting_timezone.to_s] || Time.zone
  end

  # Média, não mediana: é o que os relatórios do Chatwoot mostram, e dois números
  # diferentes para a mesma pergunta em dois sítios do produto seria pior.
  def first_response
    {
      today_seconds: average_first_response(zone.now.all_day),
      week_seconds: average_first_response(7.days.ago..zone.now)
    }
  end

  def average_first_response(range)
    scope = ReportingEvent.where(account_id: account.id, name: 'first_response', created_at: range)
    scope = scope.where(inbox_id: inbox_id) if inbox_id
    scope.average(:value)&.round
  end

  # Comparecimento é concluídas sobre concluídas mais faltas. As canceladas ficam
  # fora da taxa: cancelar com aviso não é faltar.
  def attendance
    summary = KanbanCalendar::AgendaSummary.new(account: account).call
    completed = summary[:completed][:current]
    no_show = summary[:no_show][:current]
    attended = completed + no_show
    {
      rate: attended.zero? ? nil : (completed.to_f / attended * 100).round,
      no_show: no_show,
      canceled: summary[:canceled][:current]
    }
  end

  def ai_opportunities
    metrics = RaevoAi::FunnelMetrics.new(integration: ai_integration, window_days: AI_WINDOW_DAYS).call
    { count: metrics[:opportunities_created], window_days: AI_WINDOW_DAYS }
  end

  # `waiting_since` está posto quando o contacto escreveu e ninguém respondeu:
  # a bola está connosco. As conversas são as que a pessoa pode ver.
  def waiting_24h
    scope = account.conversations.open.where(waiting_since: ...WAITING_LIMIT.ago)
    scope = scope.where(inbox_id: inbox_id) if inbox_id
    { count: Conversations::PermissionFilterService.new(scope, user, account).perform.count }
  end
end
