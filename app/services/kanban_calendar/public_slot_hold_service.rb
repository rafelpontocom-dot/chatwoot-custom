# Segura o horário que o paciente escolheu na página pública, antes de ele dar
# os dados. As agendas saem da mesma conta que ofereceu o horário — primeiro com
# vaga, rodízio ou o profissional escolhido —, por isso o que se segura é
# exatamente o que se mostrou.
class KanbanCalendar::PublicSlotHoldService
  def initialize(procedure:, starts_at:, timezone:, professional_id: nil, appointment: nil)
    @procedure = procedure
    @starts_at = starts_at
    @timezone = timezone
    @professional_id = professional_id
    @appointment = appointment
  end

  def perform!
    @procedure.with_lock do
      resources = availability.assignment_for(@starts_at)
      raise KanbanCalendar::ConflictError, [] if resources.blank?

      KanbanCalendarSlotHold.create!(
        account: @procedure.account,
        kanban_calendar_procedure: @procedure,
        kanban_calendar_appointment: @appointment,
        resource_ids: resources.map(&:id),
        starts_at: @starts_at,
        reserved_from: @starts_at - @procedure.buffer_before_minutes.minutes,
        reserved_until: @starts_at + (@procedure.duration_minutes + @procedure.buffer_after_minutes).minutes,
        timezone: @timezone,
        expires_at: @procedure.hold_minutes.minutes.from_now
      )
    end
  end

  private

  def availability
    KanbanCalendar::ProcedureAvailability.new(procedure: @procedure, professional_id: @professional_id, patient: true)
  end
end
