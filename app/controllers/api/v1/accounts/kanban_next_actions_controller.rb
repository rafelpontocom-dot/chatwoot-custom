# As tarefas dos leads na Agenda (5m): as próximas ações abertas das
# oportunidades, no período que a grelha mostra, mais as que já passaram.
#
# Como no Início, o funil vem do `policy_scope` e cada cartão passa pela policy:
# um agente pode ver o quadro e não ver a conversa do cartão.
class Api::V1::Accounts::KanbanNextActionsController < Api::V1::Accounts::BaseController
  # Uma semana cheia de uma clínica cabe com folga; o mês da grelha (42 dias) também.
  MAX_TASKS = 300
  MAX_OVERDUE = 200
  OVERDUE_ITEMS = 20
  MAX_PERIOD = 45.days

  before_action :authorize_boards
  before_action :parse_period

  def index
    render json: { tasks: visible(tasks_in_period).map { |card| payload(card) }, overdue: overdue }
  end

  private

  def authorize_boards
    authorize KanbanBoard.new(account: Current.account), :index?
  end

  def parse_period
    @starts_at = Time.zone.iso8601(params.require(:starts_at))
    @ends_at = Time.zone.iso8601(params.require(:ends_at))
    raise ArgumentError if @ends_at <= @starts_at || @ends_at - @starts_at > MAX_PERIOD
  rescue ArgumentError, ActionController::ParameterMissing
    render json: { error: 'Invalid period' }, status: :unprocessable_entity
  end

  def tasks_in_period
    open_actions.where(next_action_at: @starts_at...@ends_at).order(:next_action_at, :id).limit(MAX_TASKS)
  end

  # O total conta depois da policy; o tecto mede-se nos candidatos, como no Início.
  def overdue
    candidates = open_actions.where(next_action_at: ...Time.current).order(:next_action_at, :id).limit(MAX_OVERDUE).to_a
    late = visible(candidates)
    {
      count: late.size,
      count_capped: candidates.size >= MAX_OVERDUE,
      items: late.first(OVERDUE_ITEMS).map { |card| payload(card) }
    }
  end

  # Só as minhas por omissão (escolha de 08/10); `scope=team` mostra a equipa.
  def open_actions
    KanbanCard.active
              .where(account_id: Current.account.id, kanban_board_id: policy_scope(KanbanBoard).active.select(:id),
                     won_at: nil, lost_at: nil, next_action_completed_at: nil)
              .where.not(next_action_at: nil)
              .then { |scope| params[:scope] == 'team' ? scope : scope.where(owner_id: Current.user.id) }
              .includes(:contact, :kanban_board, :kanban_stage, :owner, :conversation, :inbox)
  end

  def visible(cards)
    cards.select { |card| policy(card).show? }
  end

  def payload(card)
    {
      kanban_card_id: card.id,
      kanban_board_id: card.kanban_board_id,
      kanban_board_name: card.kanban_board.name,
      kanban_stage_name: card.kanban_stage.name,
      subject: card.subject.presence || card.contact.name,
      contact_name: card.contact.name,
      owner_name: card.owner&.name,
      next_action_type: card.next_action_type,
      next_action_note: card.next_action_note,
      next_action_at: card.next_action_at.iso8601
    }
  end
end
