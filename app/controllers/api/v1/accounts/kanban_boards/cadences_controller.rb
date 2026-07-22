class Api::V1::Accounts::KanbanBoards::CadencesController < Api::V1::Accounts::BaseController
  before_action :fetch_kanban_board
  before_action :authorize_kanban_board
  before_action :authorize_kanban_board_update, only: [:create, :update, :destroy]
  before_action :fetch_cadence, only: [:update, :destroy]

  def index
    @cadences = @kanban_board.kanban_cadences.ordered
    render json: @cadences.map { |cadence| cadence_payload(cadence) }
  end

  def create
    cadence = @kanban_board.kanban_cadences.create!(cadence_params.merge(account: Current.account))
    render json: cadence_payload(cadence), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence, errors: e.record.errors }, status: :unprocessable_entity
  end

  def update
    @cadence.update!(cadence_params)
    render json: cadence_payload(@cadence)
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence, errors: e.record.errors }, status: :unprocessable_entity
  end

  def destroy
    @cadence.destroy!
    head :no_content
  end

  private

  def fetch_kanban_board
    @kanban_board = policy_scope(KanbanBoard).find(params[:kanban_board_id])
  end

  def authorize_kanban_board
    authorize @kanban_board, :show?
  end

  def authorize_kanban_board_update
    authorize @kanban_board, :update?
  end

  def fetch_cadence
    @cadence = @kanban_board.kanban_cadences.find(params[:id])
  end

  def cadence_params
    params.require(:cadence).permit(
      :name,
      :active,
      :pause_on_incoming_message,
      steps: [:delay_hours, :action_type, :note]
    )
  end

  def cadence_payload(cadence)
    {
      id: cadence.id,
      name: cadence.name,
      active: cadence.active,
      pause_on_incoming_message: cadence.pause_on_incoming_message,
      steps: cadence.steps
    }
  end
end
