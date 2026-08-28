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
    STATUS_GROUPS.transform_values { |statuses| totals_for(statuses) }
  end

  private

  def totals_for(statuses)
    @scope.where(status: statuses).group(:currency).order(:currency).pluck(
      :currency,
      Arel.sql('COUNT(*)'),
      Arel.sql('COALESCE(SUM(finance_payments.amount_cents), 0)')
    ).map do |currency, count, amount_cents|
      { currency: currency, count: count, amount_cents: amount_cents }
    end
  end
end
