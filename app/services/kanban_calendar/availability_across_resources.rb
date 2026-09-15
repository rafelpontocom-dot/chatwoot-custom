# A disponibilidade de uma consulta que ocupa vários recursos ao mesmo tempo —
# a profissional, a sala e o equipamento.
#
# A pergunta passou a ter mais de um recurso quando o agendamento deixou de
# escolher só «profissional ou recurso». Os horários livres de um só deles
# mentiam: deixavam escolher uma hora em que a sala estava ocupada, e a marcação
# falhava no fim, por conflito. Um horário só está livre se estiver livre para
# todos.
#
# Não repete regra nenhuma: cada recurso continua a ser avaliado pelas mesmas
# consultas de sempre, e aqui só se cruzam os resultados.
class KanbanCalendar::AvailabilityAcrossResources
  def initialize(procedure:, resources:)
    @procedure = procedure
    @resources = resources
  end

  def slots(date:)
    por_recurso = @resources.map do |resource|
      KanbanCalendar::AvailabilitySlotsQuery.new(resource: resource, procedure: @procedure, date: date).call
    end
    # Compara o instante e não o objeto: recursos com fusos diferentes devolvem
    # o mesmo momento escrito de maneiras diferentes.
    restantes = por_recurso.drop(1).map { |slots| slots.to_set(&:to_i) }
    por_recurso.first.select { |slot| restantes.all? { |instantes| instantes.include?(slot.to_i) } }
  end

  def check(starts_at:)
    por_recurso = @resources.map do |resource|
      KanbanCalendar::AvailabilityCheckService.new(procedure: @procedure, resource: resource, starts_at: starts_at).call
    end
    por_recurso.first.merge(
      available: por_recurso.all? { |result| result[:available] },
      conflict: por_recurso.any? { |result| result[:conflict] },
      resource_allowed: por_recurso.all? { |result| result[:resource_allowed] }
    )
  end
end
