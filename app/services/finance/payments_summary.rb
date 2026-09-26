class Finance::PaymentsSummary
  STATUS_GROUPS = {
    open: %w[draft pending confirmed],
    received: ['received'],
    overdue: ['overdue']
  }.freeze

  def initialize(scope:)
    @scope = scope
  end

  def call
    STATUS_GROUPS.transform_values { |statuses| totals_for(@scope, statuses) }.merge(
      # O cartão de indicador do sistema aprovado mostra o número, a variação e o
      # contexto — e sem estes dois recortes a variação teria de ser inventada.
      # O recebido compara-se por `paid_at`, não por `created_at`: uma cobrança
      # criada em agosto e paga em setembro é receita de setembro.
      month: {
        received: totals_for(paid_between(month_start, month_start.next_month), ['received']),
        received_previous: totals_for(
          paid_between(month_start.prev_month, month_start), ['received']
        )
      },
      # A idade da cobrança mais antiga em atraso — «1 cobrança · 16 dias».
      overdue_oldest_due_on: @scope.where(status: 'overdue').minimum(:due_on)
    )
  end

  private

  def month_start
    Time.zone.today.beginning_of_month
  end

  def paid_between(from, to)
    @scope.where(paid_at: from.beginning_of_day...to.beginning_of_day)
  end

  def totals_for(scope, statuses)
    scope.where(status: statuses).group(:currency).order(:currency).pluck(
      :currency,
      Arel.sql('COUNT(*)'),
      Arel.sql('COALESCE(SUM(finance_payments.amount_cents), 0)')
    ).map do |currency, count, amount_cents|
      { currency: currency, count: count, amount_cents: amount_cents }
    end
  end
end
