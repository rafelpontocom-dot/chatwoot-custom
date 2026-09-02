# Ler o ficheiro de uma importação.
#
# Ficheiros exportados de outros CRMs chegam em latin-1, com BOM à frente, ou
# com bytes que não são UTF-8 nenhum. Isto estava escrito dentro do job dos
# contactos; a importação de oportunidades precisa do mesmo, e duas cópias
# divergem sempre.
module DataImportCsv
  extend ActiveSupport::Concern

  private

  def csv_reader(file)
    file.rewind
    raw_data = file.read
    utf8_data = raw_data.force_encoding('UTF-8')
    clean_data = utf8_data.valid_encoding? ? utf8_data : utf8_data.encode('UTF-16le', invalid: :replace, replace: '').encode('UTF-8')
    clean_data = clean_data.delete_prefix("\xEF\xBB\xBF")

    CSV.new(StringIO.new(clean_data), headers: true)
  end

  def with_import_file
    temp_dir = Rails.root.join('tmp/imports')
    FileUtils.mkdir_p(temp_dir)

    @data_import.import_file.open(tmpdir: temp_dir) do |file|
      file.binmode
      yield file
    end
  end

  def csv_headers
    header_row = nil
    with_import_file do |file|
      header_row = csv_reader(file).first
    end
    header_row&.headers || []
  end
end
