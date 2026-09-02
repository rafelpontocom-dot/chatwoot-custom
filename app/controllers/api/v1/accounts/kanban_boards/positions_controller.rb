class Api::V1::Accounts::KanbanBoards::PositionsController < Api::V1::Accounts::BaseController
  before_action :fetch_kanban_board

  # Move um funil uma posição para cima ou para baixo na visão geral.
  # A resposta é vazia de propósito: quem move recarrega a lista, e assim a
  # ordem que aparece é a que ficou gravada, não a que o cliente adivinhou.
  def update
    authorize @kanban_board, :reorder?
    @kanban_board.move!(params[:direction])

    head :ok
  end

  private

  def fetch_kanban_board
    @kanban_board = policy_scope(KanbanBoard).find(params[:id])
  end
end
