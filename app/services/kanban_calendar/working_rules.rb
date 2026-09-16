# De onde vêm as janelas em que uma agenda atende, para um procedimento.
#
# Três origens, na ordem em que vencem:
# 1. o procedimento tem horário próprio (`availability_mode: schedule`): as
#    janelas são dele, e da agenda só contam os bloqueios pontuais;
# 2. a agenda usa um horário com nome: as janelas são desse horário;
# 3. a agenda tem horário só dela.
#
# Oferecer horário, validar a marcação e dizer «falta horário» passam todos por
# aqui — se cada um lesse as regras à sua maneira, a prévia da configuração e a
# página pública mostrariam listas diferentes.
class KanbanCalendar::WorkingRules
  def initialize(resource:, procedure: nil, schedule: nil)
    @resource = resource
    @procedure = procedure
    @schedule = schedule
  end

  def rules
    @rules ||= if overriding_schedule
                 overriding_schedule.kanban_calendar_availability_rules.active.to_a +
                   @resource.kanban_calendar_availability_rules.active.to_a.select(&:block?)
               else
                 @resource.working_rules
               end
  end

  def timezone
    overriding_schedule&.timezone || @resource.working_timezone
  end

  def working_hours?
    rules.any? { |rule| rule.weekly_window? || rule.date_override? }
  end

  private

  # `schedule` dado de fora responde «e se esta agenda passasse a usar este
  # horário?» — é assim que se avisa antes de aplicar um horário novo.
  def overriding_schedule
    return @overriding_schedule if defined?(@overriding_schedule)

    @overriding_schedule = @schedule || (@procedure.kanban_calendar_schedule if @procedure&.availability_mode == 'schedule')
  end
end
