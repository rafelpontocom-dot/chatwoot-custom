class RaevoAi::CrmCatalog
  class InvalidCatalog < StandardError; end
  class TransitionNotAllowed < StandardError; end

  def initialize(integration:)
    @integration = integration
  end

  def resolve_board!(board_key)
    configuration = board_configuration(board_key)
    board = KanbanBoard.active.find_by(id: positive_integer(configuration['board_id']), account_id: @integration.account_id)
    raise InvalidCatalog, 'configured board is not active in the integration account' if board.blank?

    board
  end

  def resolve_field!(board_key, field_key)
    board = resolve_board!(board_key)
    configuration = field_configuration(board_key, field_key)
    validate_field_definition!(board, field_key, configuration)

    {
      key: field_key.to_s,
      type: configuration['type'],
      values: Array(configuration['values']).map(&:to_s),
      overwrite: configuration['overwrite'].to_s
    }
  end

  def resolve_stage!(board_key, event_key, current_stage_id:)
    board = resolve_board!(board_key)
    stages = board_configuration(board_key).fetch('stages', {})
    target_configuration = stages[event_key.to_s]
    raise InvalidCatalog, 'stage event is not published in the tenant catalog' if target_configuration.blank?

    target_stage = configured_stage!(board, target_configuration)
    validate_stage_transition!(stages, target_configuration, current_stage_id)
    target_stage
  end

  def resolve_initial_stage!(board_key)
    board = resolve_board!(board_key)
    configuration = board_configuration(board_key)
    raise InvalidCatalog, 'initial stage is not published in the tenant catalog' if configuration['initial_stage_id'].blank?

    configured_stage!(board, { 'stage_id' => configuration['initial_stage_id'] })
  end

  def resolve_label!(board_key, label)
    normalized_label = label.to_s.downcase
    configuration = board_configuration(board_key).fetch('labels', {}).values.find do |item|
      item['label'].to_s.downcase == normalized_label
    end
    raise InvalidCatalog, 'label is not published in the tenant catalog' if configuration.blank?

    published_label = configuration['label'].to_s.downcase
    unless @integration.account.labels.exists?(title: published_label)
      raise InvalidCatalog, 'configured label does not exist in the integration account'
    end

    published_label
  end

  def resolve_contact_name_policy!
    configuration = @integration.settings.fetch('crm', {}).fetch('contact_name', {})
    overwrite = configuration['overwrite'].to_s
    raise InvalidCatalog, 'contact name overwrite policy is not published in the tenant catalog' unless %w[always if_empty].include?(overwrite)

    { overwrite: overwrite }
  end

  private

  def board_configuration(board_key)
    boards = @integration.settings.fetch('crm', {}).fetch('boards', {})
    configuration = boards[board_key.to_s]
    raise InvalidCatalog, 'board is not published in the tenant catalog' if configuration.blank?

    configuration
  end

  def field_configuration(board_key, field_key)
    configuration = board_configuration(board_key).dig('fields', field_key.to_s)
    raise InvalidCatalog, 'field is not published in the tenant catalog' if configuration.blank?
    raise InvalidCatalog, 'configured field key does not match catalog key' unless configuration['field_key'] == field_key.to_s

    configuration
  end

  def validate_field_definition!(board, field_key, configuration)
    definition = board.configured_custom_field_definitions.find { |item| item['key'] == field_key.to_s }
    raise InvalidCatalog, 'configured field does not exist on the board' if definition.blank?
    raise InvalidCatalog, 'configured field type does not match the board' unless definition['field_type'] == configuration['type']
    raise InvalidCatalog, 'configured field overwrite policy is invalid' unless %w[always if_empty].include?(configuration['overwrite'].to_s)
    return unless configuration['type'] == 'select'

    return if normalized_values(definition['options']) == normalized_values(configuration['values'])

    raise InvalidCatalog, 'configured select field values do not match the board'
  end

  def normalized_values(values)
    Array(values).map(&:to_s).uniq.sort
  end

  def configured_stage!(board, configuration)
    stage = KanbanStage.active.find_by(
      id: positive_integer(configuration['stage_id']),
      account_id: @integration.account_id,
      kanban_board_id: board.id
    )
    raise InvalidCatalog, 'configured stage is not active on the board' if stage.blank?

    stage
  end

  def validate_stage_transition!(stages, target_configuration, current_stage_id)
    current_stage_key = stages.find { |_key, config| positive_integer(config['stage_id']) == current_stage_id.to_i }&.first
    allowed_from = Array(target_configuration['allowed_from']).map(&:to_s)
    return if allowed_from.include?(current_stage_key)

    raise TransitionNotAllowed, 'stage transition is not allowed from the current stage'
  end

  def positive_integer(value)
    integer = Integer(value)
    integer.positive? ? integer : nil
  rescue ArgumentError, TypeError
    nil
  end
end
