# O que ocupa as agendas num período, carregado uma vez: consultas, compromissos
# importados (Google, Feegow) e vagas seguradas na página pública.
#
# O calendário do mês perguntava à base de dados, para cada dia, agenda e horário
# candidato, se havia conflito — segundos por mês. Com isto a pergunta é a mesma
# e a resposta vem da memória; sem ele (`nil`), a verificação continua a ir à base.
class KanbanCalendar::Occupancy
  def initialize(resource_ids:, from:, to:)
    @intervals = Hash.new { |hash, key| hash[key] = [] }
    load_appointments(resource_ids, from, to)
    load_busy_blocks(resource_ids, from, to)
    load_holds(resource_ids, from, to)
  end

  def busy?(resource_id, from, to)
    @intervals[resource_id].any? { |starts_at, ends_at| starts_at < to && ends_at > from }
  end

  private

  def load_appointments(resource_ids, from, to)
    KanbanCalendarAppointmentResource.where(kanban_calendar_resource_id: resource_ids)
                                     .where(appointment_status: KanbanCalendarAppointment::ACTIVE_STATUSES)
                                     .where('starts_at < ? AND ends_at > ?', to, from)
                                     .pluck(:kanban_calendar_resource_id, :starts_at, :ends_at)
                                     .each { |resource_id, starts_at, ends_at| @intervals[resource_id] << [starts_at, ends_at] }
  end

  def load_busy_blocks(resource_ids, from, to)
    KanbanCalendarExternalBusyBlock.where(kanban_calendar_resource_id: resource_ids).overlapping(from, to)
                                   .pluck(:kanban_calendar_resource_id, :starts_at, :ends_at)
                                   .each { |resource_id, starts_at, ends_at| @intervals[resource_id] << [starts_at, ends_at] }
  end

  def load_holds(resource_ids, from, to)
    KanbanCalendarSlotHold.active.overlapping(from, to).where('resource_ids && ARRAY[?]::integer[]', resource_ids)
                          .pluck(:resource_ids, :reserved_from, :reserved_until).each do |ids, starts_at, ends_at|
      (ids & resource_ids).each { |resource_id| @intervals[resource_id] << [starts_at, ends_at] }
    end
  end
end
