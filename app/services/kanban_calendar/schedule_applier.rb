# Quantas consultas já marcadas ficariam fora das janelas se estas agendas
# passassem a usar este horário. A tela avisa e deixa continuar: mudar o horário
# não desmarca ninguém, mas a secretária precisa de saber quem remarcar.
class KanbanCalendar::ScheduleApplier
  HORIZON = 180.days

  def initialize(schedule:, resources:)
    @schedule = schedule
    @resources = resources
  end

  def appointments_outside
    @resources.sum do |resource|
      working_rules = KanbanCalendar::WorkingRules.new(resource: resource, schedule: @schedule)
      future_appointments(resource).count do |appointment|
        !KanbanCalendar::AvailabilityQuery.new(
          resource: resource, working_rules: working_rules, starts_at: appointment.starts_at, ends_at: appointment.ends_at
        ).available?
      end
    end
  end

  private

  def future_appointments(resource)
    resource.kanban_calendar_appointments.active.where(starts_at: Time.current..HORIZON.from_now).to_a
  end
end
