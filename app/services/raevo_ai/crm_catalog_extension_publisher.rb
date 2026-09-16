class RaevoAi::CrmCatalogExtensionPublisher
  class InvalidCatalog < StandardError; end

  def initialize(integration:)
    @integration = integration
  end

  def publish!(board_key:, fields:, stages:)
    @integration.with_lock do
      normalized_board_key = normalize_board_key!(board_key)
      board_configuration = board_configuration!(normalized_board_key)
      board = find_board!(board_configuration)
      normalized_fields = normalize_fields!(board, fields)
      normalized_stages = normalize_stages!(board, board_configuration, stages)
      persist_additions!(normalized_board_key, normalized_fields, normalized_stages)

      {
        'board_key' => normalized_board_key,
        'fields' => normalized_fields.keys.sort,
        'events' => normalized_stages.keys.sort
      }
    end
  end

  private

  def normalize_board_key!(board_key)
    normalized = board_key.to_s.strip
    raise InvalidCatalog, 'board_key is required' if normalized.blank?

    normalized
  end

  def board_configuration!(board_key)
    configuration = @integration.settings.dig('crm', 'boards', board_key)
    raise InvalidCatalog, 'board is not published in the CRM catalog' if configuration.blank?

    configuration
  end

  def find_board!(configuration)
    board = KanbanBoard.active.find_by(id: positive_integer(configuration['board_id']), account_id: @integration.account_id)
    raise InvalidCatalog, 'board is not active in the integration account' if board.blank?

    board
  end

  def normalize_fields!(board, fields)
    source = fields.respond_to?(:to_h) ? fields.to_h.deep_stringify_keys : {}
    source.to_h do |field_key, configuration|
      [field_key, normalize_field!(board, field_key, configuration)]
    end
  end

  def normalize_field!(board, field_key, configuration)
    normalized_key = field_key.to_s.strip
    raise InvalidCatalog, 'field key is invalid' unless normalized_key.match?(/\A[a-z][a-z0-9_]*\z/)

    source = configuration.respond_to?(:to_h) ? configuration.to_h.deep_stringify_keys : {}
    definition = field_definition!(board, normalized_key)
    type, overwrite = field_settings!(definition, source)
    values = field_values!(definition, type, source)

    { 'field_key' => normalized_key, 'type' => type, 'values' => values, 'overwrite' => overwrite }
  end

  def field_definition!(board, field_key)
    definition = board.configured_custom_field_definitions.find { |item| item['key'] == field_key }
    raise InvalidCatalog, 'configured field does not exist on the board' if definition.blank?

    definition
  end

  def field_settings!(definition, source)
    type = source['type'].to_s
    overwrite = source['overwrite'].to_s
    raise InvalidCatalog, 'configured field type does not match the board' unless definition['field_type'] == type
    raise InvalidCatalog, 'configured field overwrite policy is invalid' unless %w[always if_empty].include?(overwrite)

    [type, overwrite]
  end

  def field_values!(definition, type, source)
    values = Array(source['values']).map(&:to_s)
    return values unless type == 'select'
    return values if normalized_values(definition['options']) == normalized_values(values)

    raise InvalidCatalog, 'configured select field values do not match the board'
  end

  def normalize_stages!(board, board_configuration, stages)
    source = stages.respond_to?(:to_h) ? stages.to_h.deep_stringify_keys : {}
    published_stages = board_configuration['stages']
    published_event_keys = published_stages.is_a?(Hash) ? published_stages.keys : []
    requested_event_keys = source.keys

    source.to_h do |event_key, configuration|
      [event_key, normalize_stage!(board, event_key, configuration, published_event_keys + requested_event_keys)]
    end
  end

  def normalize_stage!(board, event_key, configuration, allowed_event_keys)
    normalized_event_key = event_key.to_s.strip
    raise InvalidCatalog, 'stage event key is invalid' unless normalized_event_key.match?(/\A[a-z][a-z0-9_]*\z/)

    source = configuration.respond_to?(:to_h) ? configuration.to_h.deep_stringify_keys : {}
    stage = published_stage!(board, source['stage_id'])
    allowed_from = Array(source['allowed_from']).map(&:to_s).map(&:strip).reject(&:blank?).uniq
    validate_allowed_from!(allowed_from, allowed_event_keys)

    { 'stage_id' => stage.id, 'allowed_from' => allowed_from }
  end

  def published_stage!(board, stage_id)
    stage = board.kanban_stages.active.find_by(id: positive_integer(stage_id))
    raise InvalidCatalog, 'stage is not active on the published board' if stage.blank?

    stage
  end

  def validate_allowed_from!(allowed_from, allowed_event_keys)
    return if allowed_from.all? { |source_key| allowed_event_keys.include?(source_key) }

    raise InvalidCatalog, 'allowed_from references an unpublished event'
  end

  def persist_additions!(board_key, fields, stages)
    settings = @integration.settings.deep_dup
    board = settings.fetch('crm').fetch('boards').fetch(board_key)
    existing_fields = board['fields'] ||= {}
    existing_stages = board['stages'] ||= {}

    reject_conflicting_entries!(existing_fields, fields, 'field')
    reject_conflicting_entries!(existing_stages, stages, 'stage event')
    board['fields'] = existing_fields.merge(fields)
    board['stages'] = existing_stages.merge(stages)
    @integration.update!(settings: settings)
  end

  def reject_conflicting_entries!(existing, additions, label)
    additions.each do |key, configuration|
      next if existing[key].blank? || existing[key] == configuration

      raise InvalidCatalog, "#{label} is already published with a different configuration"
    end
  end

  def normalized_values(values)
    Array(values).map(&:to_s).uniq.sort
  end

  def positive_integer(value)
    integer = Integer(value)
    integer.positive? ? integer : nil
  rescue ArgumentError, TypeError
    nil
  end
end
