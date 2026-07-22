class Api::V1::Accounts::KanbanBoards::CadenceEnrollmentsController < Api::V1::Accounts::BaseController
  before_action :fetch_kanban_board
  before_action :fetch_kanban_card
  before_action :authorize_kanban_card

  def show
    enrollment = @kanban_card.kanban_cadence_enrollments.includes(:kanban_cadence).order(created_at: :desc).first
    render json: enrollment_payload(enrollment)
  end

  def create
    cadence = @kanban_board.kanban_cadences.active.find(enrollment_params[:cadence_id])
    enrollment = KanbanCadences::EnrollService.new(card: @kanban_card, cadence: cadence, user: Current.user).call
    render json: enrollment_payload(enrollment), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence, errors: e.record.errors }, status: :unprocessable_entity
  end

  def destroy
    @kanban_card.kanban_cadence_enrollments.where(status: %w[active awaiting_completion]).update_all( # rubocop:disable Rails/SkipsModelValidations
      status: 'canceled',
      next_run_at: nil,
      updated_at: Time.current
    )
    head :no_content
  end

  private

  def fetch_kanban_board
    @kanban_board = policy_scope(KanbanBoard).find(params[:kanban_board_id])
  end

  def fetch_kanban_card
    @kanban_card = @kanban_board.kanban_cards.active.joins(:kanban_stage).merge(KanbanStage.active).find(params[:id])
  end

  def authorize_kanban_card
    authorize @kanban_card, action_name == 'show' ? :show? : :update?
  end

  def enrollment_params
    params.require(:enrollment).permit(:cadence_id)
  end

  def enrollment_payload(enrollment)
    return { enrollment: nil } if enrollment.blank?

    {
      enrollment: {
        id: enrollment.id,
        status: enrollment.status,
        current_step: enrollment.current_step,
        next_run_at: enrollment.next_run_at&.iso8601,
        started_at: enrollment.started_at&.iso8601,
        paused_at: enrollment.paused_at&.iso8601,
        completed_at: enrollment.completed_at&.iso8601,
        cadence: {
          id: enrollment.kanban_cadence.id,
          name: enrollment.kanban_cadence.name,
          steps: enrollment.kanban_cadence.steps
        }
      }
    }
  end
end
