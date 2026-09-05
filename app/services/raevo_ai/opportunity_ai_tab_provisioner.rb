class RaevoAi::OpportunityAiTabProvisioner
  class InvalidBoard < StandardError; end

  DEFAULT_FIELDS = [
    { 'key' => 'raevo_ai_summary', 'label' => 'Resumo do atendimento', 'field_type' => 'textarea' },
    {
      'key' => 'raevo_ai_status', 'label' => 'Status do atendimento', 'field_type' => 'select',
      'options' => %w[em_atendimento qualificado pre_agendado agendado handoff_humano bloqueado]
    },
    { 'key' => 'raevo_ai_next_action', 'label' => 'Próxima ação da IA', 'field_type' => 'text' },
    { 'key' => 'raevo_ai_handoff_reason', 'label' => 'Motivo do handoff', 'field_type' => 'textarea' },
    { 'key' => 'raevo_ai_service_interest', 'label' => 'Interesse ou serviço', 'field_type' => 'text' },
    { 'key' => 'raevo_ai_scheduling_preference', 'label' => 'Preferência de agenda', 'field_type' => 'text' },
    { 'key' => 'raevo_ai_last_action_at', 'label' => 'Última ação da IA', 'field_type' => 'datetime' },
    {
      'key' => 'raevo_ai_booking_status', 'label' => 'Status do agendamento', 'field_type' => 'select',
      'options' => %w[nao_solicitado em_agendamento agendado aguardando_confirmacao cancelado]
    },
    {
      'key' => 'raevo_ai_payment_status', 'label' => 'Status do pagamento', 'field_type' => 'select',
      'options' => %w[nao_enviado link_enviado pendente pago falhou]
    }
  ].freeze

  def initialize(integration:)
    @integration = integration
  end

  def configure!(board_ids:, enabled:)
    boards = enabled ? selected_boards!(board_ids) : []
    ActiveRecord::Base.transaction do
      boards.each { |board| provision_board!(board) }
      update_integration_settings!(boards, enabled)
    end

    { 'enabled' => enabled, 'board_ids' => boards.map(&:id) }
  end

  def configuration
    configuration = @integration.settings.fetch('opportunity_ai_tab', {})
    {
      'enabled' => configuration['enabled'] == true,
      'board_ids' => Array(configuration['board_ids']).map(&:to_i).select(&:positive?).uniq
    }
  end

  private

  def selected_boards!(board_ids)
    ids = Array(board_ids).map(&:to_i).select(&:positive?).uniq
    raise InvalidBoard, 'at least one CRM board must be selected when the IA tab is enabled' if ids.empty?

    boards = KanbanBoard.active.where(account_id: @integration.account_id, id: ids).order(:id).to_a
    raise InvalidBoard, 'each selected board must belong to the integration account' unless boards.size == ids.size
    raise InvalidBoard, 'each selected board must be published in the CRM catalog' unless boards.all? { |board| crm_board_configuration(board) }

    validate_default_field_compatibility!(boards)
    boards
  end

  def validate_default_field_compatibility!(boards)
    boards.each do |board|
      existing_definitions = board.configured_custom_field_definitions.index_by { |definition| definition['key'] }

      DEFAULT_FIELDS.each do |field|
        existing_definition = existing_definitions[field['key']]
        next if existing_definition.blank? || compatible_default_field?(existing_definition, field)

        raise InvalidBoard, "board #{board.id} has an incompatible IA field definition for #{field['key']}"
      end
    end
  end

  def compatible_default_field?(existing_definition, field)
    return false unless existing_definition['field_type'] == field['field_type']
    return true unless field['field_type'] == 'select'

    normalized_options(existing_definition['options']) == normalized_options(field['options'])
  end

  def normalized_options(options)
    Array(options).map(&:to_s).uniq.sort
  end

  def provision_board!(board)
    definitions = board.configured_custom_field_definitions.reject do |definition|
      DEFAULT_FIELDS.any? { |field| field['key'] == definition['key'] }
    end
    first_position = definitions.size + 1
    definitions.concat(DEFAULT_FIELDS.map.with_index do |field, index|
      field.merge('layout' => { 'section' => 'ai', 'position' => first_position + index, 'width' => 'full' })
    end)

    sections = board.configured_custom_field_sections.reject { |section| section['key'] == 'ai' }
    sections << { 'key' => 'ai', 'label' => 'IA', 'color' => 'teal', 'groups' => [] }
    board.update!(custom_field_definitions: definitions, custom_field_sections: sections)
  end

  def update_integration_settings!(boards, enabled)
    settings = @integration.settings.deep_dup
    settings['opportunity_ai_tab'] = {
      'enabled' => enabled,
      'board_ids' => boards.map(&:id)
    }
    boards.each { |board| publish_default_fields!(settings, board) } if enabled
    @integration.update!(settings: settings)
  end

  def publish_default_fields!(settings, board)
    configuration = settings.fetch('crm', {}).fetch('boards', {}).find do |_key, value|
      value['board_id'].to_i == board.id
    end&.last
    fields = configuration['fields'] ||= {}
    DEFAULT_FIELDS.each do |field|
      fields[field['key']] = {
        'field_key' => field['key'],
        'type' => field['field_type'],
        'values' => Array(field['options']),
        'overwrite' => 'always'
      }
    end
  end

  def crm_board_configuration(board)
    @integration.settings.fetch('crm', {}).fetch('boards', {}).values.find do |configuration|
      configuration['board_id'].to_i == board.id
    end
  end
end
