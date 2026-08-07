class KanbanCalendar::AppointmentSeriesBuilder
  Attributes = Data.define(
    :account,
    :contact,
    :card,
    :procedure,
    :starts_at,
    :timezone,
    :occurrence_count,
    :interval_kind,
    :interval_days
  )

  def initialize(attributes:)
    @attributes = Attributes.new(**attributes)
  end

  def build
    account.kanban_calendar_appointment_series.create!(
      contact: contact,
      kanban_card: card,
      kanban_calendar_procedure: procedure,
      planned_count: occurrence_count,
      interval_kind: interval_kind,
      interval_days: interval_kind == 'days' ? interval_days : nil,
      timezone: timezone,
      started_at: starts_at
    )
  end

  def build_appointment(series:, occurrence_starts_at:, occurrence_number:)
    series.kanban_calendar_appointments.build(
      account: account,
      contact: contact,
      kanban_card: card,
      kanban_calendar_procedure: procedure,
      starts_at: occurrence_starts_at,
      ends_at: occurrence_starts_at + procedure.duration_minutes.minutes,
      timezone: timezone,
      occurrence_number: occurrence_number
    )
  end

  delegate :account, :contact, :card, :procedure, :starts_at, :timezone, :occurrence_count, :interval_kind, :interval_days, to: :@attributes
end
