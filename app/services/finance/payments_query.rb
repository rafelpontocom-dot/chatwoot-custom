class Finance::PaymentsQuery
  def initialize(scope:, filters:)
    @scope = scope
    @filters = filters
  end

  def call
    payments = filter_by_status(@scope)
    payments = filter_by_due_date(payments, :due_from, :>=)
    payments = filter_by_due_date(payments, :due_to, :<=)
    payments = filter_by_owner(payments)

    filter_by_query(payments)
  end

  private

  def filter_by_status(payments)
    return payments unless FinancePayment::STATUSES.include?(@filters[:status])

    payments.where(status: @filters[:status])
  end

  def filter_by_due_date(payments, filter_key, operator)
    date = parse_date(@filters[filter_key])
    return payments unless date

    payments.where("finance_payments.due_on #{operator} ?", date)
  end

  def filter_by_query(payments)
    query = @filters[:query].to_s.strip
    return payments if query.blank?

    term = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
    payments.left_joins(:contact, :kanban_card).where(
      <<~SQL.squish,
        finance_payments.description ILIKE :term OR
        finance_payments.external_reference ILIKE :term OR
        contacts.name ILIKE :term OR
        contacts.email ILIKE :term OR
        contacts.phone_number ILIKE :term OR
        kanban_cards.subject ILIKE :term
      SQL
      term: term
    )
  end

  def filter_by_owner(payments)
    return payments if @filters[:owner_id].blank?

    payments.joins(:kanban_card).where(kanban_cards: { owner_id: @filters[:owner_id] })
  end

  def parse_date(value)
    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end
end
