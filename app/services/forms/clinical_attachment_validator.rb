class Forms::ClinicalAttachmentValidator
  MAXIMUM_FILE_COUNT = 5
  MAXIMUM_FILE_SIZE = 10.megabytes
  CONTENT_TYPES = %w[application/pdf image/heic image/heif image/jpeg image/png].freeze
  EXTENSIONS = %w[.heic .heif .jpeg .jpg .pdf .png].freeze

  attr_reader :errors

  def initialize(schema:, answers:, attachments:)
    @schema = schema.to_h
    @answers = answers.to_h.stringify_keys
    @attachments = attachments.to_h.stringify_keys
    @errors = []
  end

  def valid?
    validate_attachments unless @validated
    errors.empty?
  end

  def files
    @files ||= @attachments.values.flat_map { |value| normalize_files(value) }.compact
  end

  private

  def validate_attachments
    @validated = true
    validate_attachment_keys
    validate_required_fields
    validate_file_count
    files.each { |file| validate_file(file) }
  end

  def validate_attachment_keys
    unknown_keys = @attachments.keys - attachment_fields.pluck('key')
    errors << 'arquivos não pertencem a uma pergunta publicada' if unknown_keys.present?
  end

  def validate_required_fields
    attachment_fields.select { |field| field['required'] }.each do |field|
      next if Array(@attachments[field['key']]).compact.present?

      errors << "#{field['label']} não pode ficar em branco"
    end
  end

  def validate_file_count
    return if files.size <= MAXIMUM_FILE_COUNT

    errors << "envie no máximo #{MAXIMUM_FILE_COUNT} arquivos"
  end

  def validate_file(file)
    unless file.respond_to?(:tempfile) && file.tempfile.present?
      errors << 'arquivo enviado é inválido'
      return
    end

    errors << 'arquivo deve ter no máximo 10 MB' if file_size(file) > MAXIMUM_FILE_SIZE
    return if CONTENT_TYPES.include?(file.content_type) && EXTENSIONS.include?(File.extname(file.original_filename).downcase)

    errors << 'envie um arquivo permitido: PDF, JPG, PNG ou HEIC'
  end

  def attachment_fields
    @attachment_fields ||= @schema.fetch('sections', []).flat_map do |section|
      section.fetch('fields', []).select { |field| field['type'] == 'attachment' && visible?(field) }
    end
  end

  def visible?(field)
    condition = field['visible_when'].to_h
    return true if condition.blank?

    condition['operator'] == 'equals' && @answers[condition['field']] == condition['value']
  end

  def file_size(file)
    return file.size if file.respond_to?(:size)

    file.tempfile.size
  end

  def normalize_files(value)
    return value.values.flat_map { |item| normalize_files(item) } if value.respond_to?(:to_unsafe_h)
    return value.values.flat_map { |item| normalize_files(item) } if value.is_a?(Hash)

    Array(value)
  end
end
