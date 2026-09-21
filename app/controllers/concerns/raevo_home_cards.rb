# Os três cartões de apoio do Início: agenda do dia, cobranças vencidas e
# oportunidades paradas. Vivem fora do controlador porque são três consultas
# independentes com regras próprias de visibilidade — e porque um controlador que
# cresce sem parar é o que o AGENTS.md manda evitar.
module RaevoHomeCards
  extend ActiveSupport::Concern

  # Cobranças e oportunidades paradas são listas de apoio: três linhas e o total.
  RAIL_ITEMS = 3
  STALE_CANDIDATE_LIMIT = 200

  private

    # ─────────── Os três cartões aprovados a 21/09 ───────────
    #
    # Cada um devolve `nil` quando o módulo não está em uso, e `{count:, items:}`
    # quando está. `nil` é «não mostrar o cartão»; lista vazia é «está ligado e
    # hoje não há nada». Um cartão vazio de um módulo que a clínica não usa é pior
    # do que cartão nenhum.

    # O dia é o da conta, não o do servidor. Uma clínica em Lisboa num servidor em
    # UTC via a agenda do dia errado a partir da meia-noite.
    def account_zone
      ActiveSupport::TimeZone[Current.account.reporting_timezone.to_s] || Time.zone
    end

    # A Agenda não tem interruptor de módulo como o Financeiro: quem não a usa não
    # tem marcações e vê o estado vazio, que é informação e não ruído.
    def today_appointments
      scope = Current.account.kanban_calendar_appointments
                     .active
                     .where(starts_at: account_zone.now.all_day)

      {
        count: scope.count,
        items: scope.includes(:contact, :kanban_calendar_procedure)
                    .order(starts_at: :asc, id: :asc)
                    .limit(MAX_ITEMS)
                    .map { |appointment| appointment_payload(appointment) }
      }
    end

    def appointment_payload(appointment)
      {
        id: appointment.id,
        starts_at: appointment.starts_at.iso8601,
        status: appointment.status,
        contact_name: appointment.contact.name,
        procedure_name: appointment.kanban_calendar_procedure.name,
        kanban_card_id: appointment.kanban_card_id
      }
    end

    def finance_setting
      return @finance_setting if defined?(@finance_setting)

      @finance_setting = Current.account.finance_module_setting
    end

    # Duas condições, não uma: o módulo tem de estar ligado na conta E a pessoa tem
    # de poder ver cobranças. Secretaria sem permissão financeira não vê o cartão.
    def finance_visible?
      finance_setting&.enabled? && policy(finance_setting).view_payments?
    end

    def overdue_payments
      return unless finance_visible?

      scope = Current.account.finance_payments.where(status: 'overdue')

      {
        count: scope.count,
        items: scope.includes(:contact)
                    .order(due_on: :asc, id: :asc)
                    .limit(RAIL_ITEMS)
                    .map { |payment| overdue_payment_payload(payment) }
      }
    end

    def overdue_payment_payload(payment)
      {
        id: payment.id,
        contact_name: payment.contact.name,
        amount_cents: payment.amount_cents,
        currency: payment.currency,
        due_on: payment.due_on&.iso8601,
        kanban_card_id: payment.kanban_card_id
      }
    end

    # «Parada» não é uma coluna: `stale_in_stage?` compara `stage_entered_at` com o
    # limite DAQUELA etapa. É método de Ruby, por isso carrega-se uma janela e
    # filtra-se, como nas ações atrasadas — e o tecto é dito no ecrã.
    def stale_opportunities
      board_ids = selected_board_id ? [selected_board_id] : policy_scope(KanbanBoard).pluck(:id)
      return { count: 0, count_capped: false, items: [] } if board_ids.empty?

      candidates = stale_candidates(board_ids)
      visible = candidates.select { |card| card.stale_in_stage? && policy(card).show? }

      {
        count: visible.size,
        count_capped: candidates.size >= STALE_CANDIDATE_LIMIT,
        items: visible.first(RAIL_ITEMS).map { |card| stale_opportunity_payload(card) }
      }
    end

    def stale_candidates(board_ids)
      KanbanCard.open_opportunities
                .where(account_id: Current.account.id, kanban_board_id: board_ids)
                .where.not(stage_entered_at: nil)
                .includes(:contact, :kanban_board, :kanban_stage)
                .order(stage_entered_at: :asc, id: :asc)
                .limit(STALE_CANDIDATE_LIMIT)
                .to_a
    end

    def stale_opportunity_payload(card)
      {
        kanban_card_id: card.id,
        kanban_board_id: card.kanban_board_id,
        kanban_board_name: card.kanban_board.name,
        kanban_stage_name: card.kanban_stage.name,
        subject: card.subject.presence || card.contact.name,
        stage_entered_at: card.stage_entered_at.iso8601,
        stale_days: card.kanban_board.stale_days_for_stage(card.kanban_stage_id)
      }
    end
end
