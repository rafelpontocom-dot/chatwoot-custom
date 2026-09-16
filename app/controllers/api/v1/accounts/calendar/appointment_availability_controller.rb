# Quando há lugar na agenda. Fica fora do controller de consultas: não é CRUD de
# consulta, e a pergunta tem três formas — um dia, os próximos dias com vaga, e
# um horário concreto.
class Api::V1::Accounts::Calendar::AppointmentAvailabilityController < Api::V1::Accounts::BaseController
  def show
    authorize KanbanCalendarAppointment, :index?
    return render_slots if params[:date].present? || params[:days].present?

    starts_at = Time.zone.parse(params.require(:starts_at))
    return render json: { message: 'A valid start time is required' }, status: :unprocessable_entity if starts_at.blank?

    render json: availability.check(starts_at: starts_at)
  end

  private

  # Com data, os horários daquele dia; sem ela, os próximos dias com vaga — que é
  # o que a tela precisa assim que a agenda é escolhida.
  def render_slots
    render json: if params[:date].present?
                   availability.day_availability(date: Date.iso8601(params[:date]))
                 else
                   availability.upcoming_availability(from: from_date, days: params[:days].to_i)
                 end
  rescue Date::Error
    render json: { message: 'A valid date is required' }, status: :unprocessable_entity
  end

  def from_date
    params[:from].present? ? Date.iso8601(params[:from]) : Time.zone.today
  end

  def availability
    KanbanCalendar::AvailabilityAcrossResources.new(procedure: scoped_procedure, resources: scoped_resources)
  end

  def scoped_procedure
    policy_scope(KanbanCalendarProcedure).active.find(params.require(:procedure_id))
  end

  def scoped_resource
    policy_scope(KanbanCalendarResource).active.find(params.require(:resource_id))
  end

  # Uma consulta pode ocupar profissional, sala e equipamento ao mesmo tempo, e
  # a disponibilidade tem de valer para todos. `resource_id` continua aceite:
  # a oportunidade do Kanban e o runtime ainda perguntam por um recurso só.
  def scoped_resources
    ids = Array(params[:resource_ids]).compact_blank.uniq
    return [scoped_resource] if ids.empty?

    # `find` com lista lança RecordNotFound se faltar algum: um id de outra conta
    # é recusado em vez de ignorado.
    policy_scope(KanbanCalendarResource).active.find(ids)
  end

  def availability_across_resources
    KanbanCalendar::AvailabilityAcrossResources.new(
      procedure: scoped_availability_procedure,
      resources: scoped_resources
    )
  end
end
