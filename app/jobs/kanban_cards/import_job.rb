# Importa um CSV de oportunidades.
#
# Quem migra de outro CRM traz centenas de linhas de uma vez. O que interessa é
# que no fim se saiba exactamente o que entrou e o que não entrou, e porquê: as
# rejeitadas voltam num CSV com a coluna `errors`, pronto a corrigir e a
# reenviar.
class KanbanCards::ImportJob < ApplicationJob
  include DataImportCsv

  queue_as :low
  retry_on ActiveStorage::FileNotFoundError, wait: 1.minute, attempts: 3

  def perform(data_import)
    @data_import = data_import
    @data_import.update!(status: :processing)

    importadas, rejeitadas = processar
    @data_import.update!(status: :completed, processed_records: importadas, total_records: importadas + rejeitadas.length)
    guardar_rejeitadas(rejeitadas)
  rescue CSV::MalformedCSVError, ActiveRecord::RecordNotFound => e
    @data_import.update!(status: :failed, processing_errors: e.message)
  end

  private

  def processar
    importadas = 0
    rejeitadas = []

    with_import_file do |file|
      csv_reader(file).each do |row|
        resultado = importer.import(row.to_h)
        if resultado.ok?
          importadas += 1
        else
          rejeitadas << row.to_h.merge('errors' => resultado.error)
        end
      end
    end

    [importadas, rejeitadas]
  end

  def importer
    @importer ||= KanbanCards::RowImporter.new(
      board: board,
      fallback_stage: fallback_stage,
      mapping: meta['mapping'] || {}
    )
  end

  def board
    @board ||= KanbanBoard.active.find_by!(account_id: @data_import.account_id, id: meta['board_id'])
  end

  # Sem etapa de recurso escolhida, a primeira do funil. Um ficheiro sem coluna
  # de etapa continua a entrar; não é razão para perder a importação inteira.
  def fallback_stage
    @fallback_stage ||= board.kanban_stages.active.find_by(id: meta['fallback_stage_id']) ||
                        board.kanban_stages.active.ordered.first
  end

  def meta
    @data_import.meta || {}
  end

  def guardar_rejeitadas(rejeitadas)
    return if rejeitadas.blank?

    csv = CSV.generate do |linha|
      linha << rejeitadas.first.keys
      rejeitadas.each { |registo| linha << registo.values }
    end

    @data_import.failed_records.attach(
      io: StringIO.new(csv),
      filename: "#{Time.zone.today.strftime('%Y%m%d')}_oportunidades.csv",
      content_type: 'text/csv'
    )
  end
end
