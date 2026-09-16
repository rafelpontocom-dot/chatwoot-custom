# Os horários de um procedimento quando quem marca não escolheu as agendas uma a
# uma — a página pública e a prévia da aba «Quando».
#
# As agendas elegíveis do procedimento formam grupos, um por tipo (profissional,
# sala, equipamento). Um horário está livre quando cada grupo tem pelo menos uma
# agenda livre nesse instante; a primeira livre de cada grupo é a que fica com a
# consulta. Isso é «primeiro com vaga». O rodízio muda só a ordem do grupo dos
# profissionais (quem recebeu consulta há mais tempo vem primeiro), e «todos
# juntos» faz de cada profissional da equipe um grupo próprio.
#
# Não repete regra de horário nenhuma: cada agenda continua a ser avaliada por
# `AvailabilitySlotsQuery`, e aqui só se combinam os resultados.
class KanbanCalendar::ProcedureAvailability
  PROFESSIONAL = 'user'.freeze

  def initialize(procedure:, professional_id: nil, patient: false, now: Time.current)
    @procedure = procedure
    @professional_id = professional_id.presence&.to_i
    @patient = patient
    @now = now
  end

  # [{ starts_at:, resources: [agenda, ...] }], por ordem de hora.
  def slots(date:)
    return [] unless bookable_day?(date)

    free = free_instants(date)
    candidates = groups.first.to_a.flat_map { |resource| free[resource.id].to_a }.uniq.sort
    candidates.filter_map { |instant| slot_at(instant, free) }
  end

  def days_with_slots(from:, to:)
    with_occupancy(from, to) { (from..to).select { |date| slots(date: date).any? } }
  end

  def upcoming(from:, days:, per_day: 6, max_days: 3)
    with_occupancy(from, from + days) do
      (from...(from + days)).each_with_object([]) do |date, found|
        day_slots = slots(date: date)
        found << { date: date, slots: day_slots.first(per_day) } if day_slots.any?
        break found if found.length >= max_days
      end
    end
  end

  def assignment_for(starts_at)
    date = starts_at.in_time_zone(timezone).to_date
    slots(date: date).find { |slot| slot[:starts_at].to_i == starts_at.to_i }&.dig(:resources)
  end

  def professionals
    @professionals ||= eligible_resources.select { |resource| resource.resource_type == PROFESSIONAL }
  end

  def timezone
    resource = groups.first&.first
    return @procedure.account.kanban_calendar_resources.first&.timezone || 'UTC' if resource.blank?

    KanbanCalendar::WorkingRules.new(resource: resource, procedure: @procedure).timezone
  end

  private

  def bookable_day?(date)
    return false if groups.empty?
    return false if @professional_id && professionals.none? { |resource| resource.id == @professional_id }

    !@patient || !limits.daily_limit_reached?(date, timezone)
  end

  def slot_at(instant, free)
    chosen = groups.map { |group| group.find { |resource| free[resource.id]&.include?(instant) } }
    return if chosen.any?(&:nil?)

    starts_at = Time.zone.at(instant)
    { starts_at: starts_at, resources: chosen } if bookable?(starts_at)
  end

  def bookable?(starts_at)
    !@patient || limits.bookable_by_patient?(starts_at, now: @now)
  end

  def free_instants(date)
    groups.flatten.uniq.index_by(&:id).transform_values do |resource|
      KanbanCalendar::AvailabilitySlotsQuery.new(
        resource: resource, procedure: @procedure, date: date, occupancy: @occupancy,
        working_rules: working_rules_for(resource), limits: limits, allowed_resource_ids: allowed_resource_ids
      ).call.to_set(&:to_i)
    end
  end

  # Um período inteiro carregado de uma vez; um dia a mais de cada lado cobre
  # fusos e intervalos antes e depois.
  def with_occupancy(from, to)
    resource_ids = groups.flatten.map(&:id).uniq
    zone = ActiveSupport::TimeZone[timezone]
    @occupancy = KanbanCalendar::Occupancy.new(
      resource_ids: resource_ids, from: zone.local(from.year, from.month, from.day) - 1.day,
      to: zone.local(to.year, to.month, to.day) + 2.days
    )
    yield
  ensure
    @occupancy = nil
  end

  def working_rules_for(resource)
    @working_rules ||= {}
    @working_rules[resource.id] ||= KanbanCalendar::WorkingRules.new(resource: resource, procedure: @procedure)
  end

  def allowed_resource_ids
    @allowed_resource_ids ||= @procedure.kanban_calendar_resource_ids
  end

  def groups
    @groups ||= begin
      by_type = eligible_resources.reject { |resource| resource.resource_type == PROFESSIONAL }.group_by(&:resource_type)
      (professional_groups + by_type.values).reject(&:empty?)
    end
  end

  def professional_groups
    return [professionals.select { |resource| resource.id == @professional_id }] if @professional_id
    return team_members.zip if @procedure.assignment_strategy == 'collective'
    return [team_members] if @procedure.kanban_calendar_team

    [professionals]
  end

  def team_members
    team = @procedure.kanban_calendar_team
    return professionals if team.blank?

    members = team.kanban_calendar_team_members.active.includes(:kanban_calendar_resource)
                  .select { |member| member.kanban_calendar_resource.active? }
    members = members.sort_by { |member| [member.last_assigned_at || Time.zone.at(0), member.kanban_calendar_resource.name] }
    members.map(&:kanban_calendar_resource)
  end

  def eligible_resources
    @eligible_resources ||= begin
      scope = @procedure.account.kanban_calendar_resources.active.includes(:kanban_calendar_schedule).order(:name)
      scope = scope.where(id: @procedure.kanban_calendar_resource_ids) if @procedure.kanban_calendar_resources.exists?
      scope.to_a
    end
  end

  def limits
    @limits ||= KanbanCalendar::ProcedureLimits.new(procedure: @procedure)
  end
end
