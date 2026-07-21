class Api::V1::Accounts::KanbanBoards::ReportsController < Api::V1::Accounts::BaseController
  before_action :fetch_kanban_board
  before_action :authorize_kanban_board

  def sales_summary
    render json: @kanban_board.sales_summary
  end

  private

  def fetch_kanban_board
    @kanban_board = policy_scope(KanbanBoard).find(params[:kanban_board_id])
  end

  def authorize_kanban_board
    authorize @kanban_board, :show?
  end
end
