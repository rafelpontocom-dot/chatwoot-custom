class Api::V1::Accounts::KanbanBoards::DuplicatesController < Api::V1::Accounts::BaseController
  before_action :fetch_kanban_board

  def create
    authorize @kanban_board, :duplicate?
    @kanban_board = KanbanBoards::DuplicateService.new(board: @kanban_board).perform!
    render template: 'api/v1/accounts/kanban_boards/create', status: :created
  end

  private

  def fetch_kanban_board
    @kanban_board = policy_scope(KanbanBoard).find(params[:id])
  end
end
