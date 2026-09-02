class Api::V1::Accounts::KanbanBoards::ImportsController < Api::V1::Accounts::BaseController
  before_action :fetch_kanban_board

  # O ecrã pergunta por aqui como correu, e é aqui que aparece o link do CSV de
  # rejeitadas — sem ele, saber o que ficou de fora era adivinhar.
  def show
    authorize @kanban_board, :show?

    render json: serialize(Current.account.data_imports.find(params[:id]))
  end

  # Recebe o CSV e devolve logo o registo da importação: o trabalho corre em
  # segundo plano, porque uma migração traz centenas de linhas e ninguém fica a
  # olhar para um pedido pendurado.
  def create
    authorize @kanban_board, :update?
    return render_missing_file if params[:import_file].blank?

    data_import = nil
    ActiveRecord::Base.transaction do
      data_import = Current.account.data_imports.create!(data_type: 'kanban_cards', meta: import_meta)
      data_import.import_file.attach(params[:import_file])
    end

    render json: serialize(data_import), status: :created
  end

  private

  def serialize(data_import)
    {
      id: data_import.id,
      status: data_import.status,
      total_records: data_import.total_records,
      processed_records: data_import.processed_records,
      processing_errors: data_import.processing_errors,
      failed_records_url: failed_records_url(data_import)
    }
  end

  def failed_records_url(data_import)
    return if data_import.failed_records.blank?

    Rails.application.routes.url_helpers.rails_blob_url(data_import.failed_records, only_path: true)
  end

  def import_meta
    {
      'board_id' => @kanban_board.id,
      'fallback_stage_id' => params[:fallback_stage_id],
      'mapping' => params[:mapping].present? ? params[:mapping].permit!.to_h : {}
    }
  end

  def render_missing_file
    render json: { error: I18n.t('errors.kanban_import.file_missing') }, status: :unprocessable_entity
  end

  def fetch_kanban_board
    @kanban_board = policy_scope(KanbanBoard).find(params[:kanban_board_id])
  end
end
