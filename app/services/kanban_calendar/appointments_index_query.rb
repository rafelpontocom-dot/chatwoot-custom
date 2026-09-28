class KanbanCalendar::AppointmentsIndexQuery
  def initialize(scope:, kanban_card:, filters:, contact: nil)
    @scope = scope
    @starts_at = filters[:starts_at]
    @ends_at = filters[:ends_at]
    @kanban_card = kanban_card
    @contact = contact
    @status = filters[:status]
    @resource_ids = Array(filters[:resource_ids]).filter_map(&:presence).map(&:to_i).uniq
    @query = filters[:q].to_s.strip
  end

  def call
    filtered_scope.distinct
  end

  private

  def filtered_scope
    result = @scope
    result = result.within(Time.zone.parse(@starts_at), Time.zone.parse(@ends_at)) if date_range_provided?
    result = result.where(kanban_card: @kanban_card) if @kanban_card
    result = result.where(contact: @contact) if @contact
    result = result.where(status: statuses_filter) if @status.present?
    result = result.merge(search_scope) if @query.present?
    result = filter_resources(result) if @resource_ids.present?
    result
  end

  # `active` não é um status gravado: é o conjunto que o indicador «Marcações
  # hoje» conta — o que ainda está de pé. Sem ele, o número contava um recorte e
  # o clique levava a outro, e os dois discordavam na cara de quem lê.
  def statuses_filter
    return KanbanCalendarAppointment::ACTIVE_STATUSES if @status.to_s == 'active'

    @status
  end

  def date_range_provided?
    @starts_at.present? && @ends_at.present?
  end

  def search_scope
    query = "%#{KanbanCalendarAppointment.sanitize_sql_like(@query)}%"
    KanbanCalendarAppointment.left_joins(:contact, :kanban_card).where(
      'contacts.name ILIKE :query OR contacts.email ILIKE :query OR contacts.phone_number ILIKE :query OR kanban_cards.subject ILIKE :query',
      query: query
    )
  end

  def filter_resources(scope)
    scope.joins(:kanban_calendar_appointment_resources).where(
      kanban_calendar_appointment_resources: { kanban_calendar_resource_id: @resource_ids }
    )
  end
end
