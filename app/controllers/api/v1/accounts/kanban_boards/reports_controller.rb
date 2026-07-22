class Api::V1::Accounts::KanbanBoards::ReportsController < Api::V1::Accounts::BaseController
  before_action :fetch_kanban_board
  before_action :authorize_kanban_board

  def sales_summary
    render json: @kanban_board.sales_summary
  end

  def activities
    @limit = params.fetch(:limit, 25).to_i.clamp(1, 50)
    @page = params.fetch(:page, 1).to_i.clamp(1, 10_000)
    @cards = activity_cards.offset((@page - 1) * @limit).limit(@limit + 1).to_a
    @has_more = @cards.length > @limit
    @cards = @cards.first(@limit)
  end

  def export
    csv = KanbanBoards::ExportCardsService.new(
      account: Current.account,
      user: Current.user,
      board: @kanban_board,
      filters: export_filters
    ).call

    send_data csv,
              filename: "kanban-#{@kanban_board.name.parameterize}-#{Time.zone.today}.csv",
              type: 'text/csv; charset=utf-8'
  end

  private

  def fetch_kanban_board
    @kanban_board = policy_scope(KanbanBoard).find(params[:kanban_board_id])
  end

  def authorize_kanban_board
    authorize @kanban_board, :report?
  end

  def activity_cards
    cards = activity_cards_scope

    cards = cards.where(owner_id: params[:owner_id]) if params[:owner_id].present?

    cards = filtered_activity_cards(cards)
    order_column = params[:view].to_s == 'appointments' ? 'starts_at' : 'next_action_at'

    cards.order(Arel.sql("kanban_cards.#{order_column} ASC NULLS LAST"), id: :asc)
  end

  def activity_cards_scope
    @kanban_board.kanban_cards.active
                 .joins(:kanban_stage)
                 .merge(KanbanStage.active)
                 .includes(:kanban_stage, :contact, :inbox, :conversation, :owner)
  end

  def filtered_activity_cards(cards)
    case params[:view].to_s
    when 'today'
      cards.where(next_action_at: Time.zone.now.all_day, next_action_completed_at: nil)
    when 'overdue'
      cards.where('next_action_at < ?', Time.zone.now)
           .where(next_action_completed_at: nil)
    when 'upcoming'
      cards.where('next_action_at > ?', Time.zone.now)
           .where(next_action_completed_at: nil)
    when 'missing'
      cards.where(next_action_at: nil, next_action_type: nil)
    when 'owner'
      cards.where(won_at: nil, lost_at: nil)
    when 'appointments'
      cards.where(won_at: nil, lost_at: nil)
           .where('starts_at >= ?', Time.zone.now.beginning_of_day)
    else
      cards
    end
  end

  def export_filters
    {
      inbox_ids: normalized_export_inbox_ids,
      assignee_ids: normalized_export_assignee_ids,
      next_action: params[:next_action].presence,
      status: params[:status].presence,
      search: params[:search].presence,
      sort: params[:sort].presence
    }
  end

  def normalized_export_inbox_ids
    ids = Array(params[:inbox_ids]).filter_map(&:presence).map(&:to_i).uniq
    return if ids.blank?

    validate_export_ids!(Inbox, ids)
    ids & board_filterable_inbox_ids(ids)
  end

  def normalized_export_assignee_ids
    ids = Array(params[:assignee_ids]).filter_map(&:presence).map(&:to_i).uniq
    return if ids.blank?

    validate_export_ids!(User, ids)
    ids
  end

  def validate_export_ids!(model, ids)
    scope = model.where(account_id: Current.account.id, id: ids)
    return if scope.count == ids.length

    raise ActiveRecord::RecordNotFound
  end

  def board_filterable_inbox_ids(inbox_ids)
    return inbox_ids if @kanban_board.all_inboxes?

    @kanban_board.kanban_board_inboxes.where(inbox_id: inbox_ids).pluck(:inbox_id)
  end
end
