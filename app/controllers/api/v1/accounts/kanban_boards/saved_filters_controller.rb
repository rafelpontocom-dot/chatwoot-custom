class Api::V1::Accounts::KanbanBoards::SavedFiltersController < Api::V1::Accounts::BaseController
  before_action :fetch_kanban_board
  before_action :authorize_kanban_board_show
  before_action :fetch_saved_filter, only: [:update, :destroy]

  def index
    render json: current_user_filters.order(:name, :id).map { |filter| filter_payload(filter) }
  end

  def create
    filter = current_user_filters.create!(saved_filter_params.merge(account: Current.account))
    render json: filter_payload(filter), status: :created
  end

  def update
    @saved_filter.update!(saved_filter_params)
    render json: filter_payload(@saved_filter)
  end

  def destroy
    @saved_filter.destroy!
    head :no_content
  end

  private

  def fetch_kanban_board
    @kanban_board = policy_scope(KanbanBoard).find(params[:kanban_board_id])
  end

  def authorize_kanban_board_show
    authorize @kanban_board, :show?
  end

  def fetch_saved_filter
    @saved_filter = current_user_filters.find(params[:id])
  end

  def current_user_filters
    @kanban_board.kanban_saved_filters.where(user: Current.user)
  end

  def saved_filter_params
    params.require(:saved_filter).permit(
      :name,
      filters: [:search, :next_action, :status, :sort, { inbox_ids: [], assignee_ids: [] }]
    )
  end

  def filter_payload(filter)
    {
      id: filter.id,
      name: filter.name,
      filters: filter.filters,
      created_at: filter.created_at.iso8601,
      updated_at: filter.updated_at.iso8601
    }
  end
end
