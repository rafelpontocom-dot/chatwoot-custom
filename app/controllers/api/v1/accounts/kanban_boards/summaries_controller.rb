class Api::V1::Accounts::KanbanBoards::SummariesController < Api::V1::Accounts::BaseController
  before_action :fetch_kanban_board

  # Os quatro indicadores que abrem o Pipeline no sistema aprovado.
  #
  # Controlador próprio e não uma acção do `KanbanBoardsController`, por duas
  # razões: aquele já estava a 175/175 no `Metrics/ClassLength`, e o quadro é
  # pedido a cada arrastar de cartão — as quatro agregações não têm de correr
  # outra vez por causa disso.
  def show
    authorize @kanban_board, :show?
    render json: KanbanBoards::CommercialSummary.new(board: @kanban_board).call
  end

  private

  def fetch_kanban_board
    @kanban_board = policy_scope(KanbanBoard).find(params[:id])
  end
end
