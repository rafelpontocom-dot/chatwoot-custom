class KanbanCalendar::AgendaSummary
  # Os indicadores que abrem a Agenda no sistema aprovado.
  #
  # **A taxa de ocupação do artefacto não está aqui, e é deliberado.** Calculá-la
  # exige cruzar `KanbanCalendarAvailabilityRule` (por dia de semana e por data,
  # por recurso), os blocos externos e as durações — e cada um desses tem casos que
  # mudariam o número. Uma ocupação errada é pior do que nenhuma: é sobre ela que
  # se decide abrir ou fechar agenda. Entra quando for medida a sério.
  #
  # O que está aqui é exato: contagens de estado, que a coluna `status` conhece.
  def initialize(account:)
    @account = account
  end

  def call
    {
      today: today,
      completed: { current: count_with('completed', current_month), previous: count_with('completed', previous_month) },
      no_show: { current: count_with('no_show', current_month), previous: count_with('no_show', previous_month) },
      canceled: { current: count_with('canceled', current_month), previous: count_with('canceled', previous_month) },
      month_total: appointments.where(starts_at: current_month).count
    }
  end

  private

  def appointments
    @account.kanban_calendar_appointments
  end

  # A mesma resolução que `RaevoHomeCards#account_zone` usa. `Account` não tem
  # `timezone`: tem `reporting_timezone` num `store_accessor`.
  def zone
    ActiveSupport::TimeZone[@account.reporting_timezone.to_s] || Time.zone
  end

  # Hoje conta o que ainda está de pé — marcado, confirmado ou com o doente já
  # na clínica. Uma falta de ontem não é «marcação de hoje».
  def today
    escopo = appointments.active.where(starts_at: zone.now.all_day)
    {
      count: escopo.count,
      unconfirmed: escopo.where(status: 'scheduled').count
    }
  end

  def current_month
    inicio = zone.now.beginning_of_month
    inicio...inicio.next_month
  end

  def previous_month
    inicio = zone.now.beginning_of_month - 1.month
    inicio...inicio.next_month
  end

  def count_with(status, range)
    appointments.where(status: status, starts_at: range).count
  end
end
