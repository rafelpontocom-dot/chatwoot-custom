class RaevoAi::CrmCatalogPublisher
  class InvalidCatalog < StandardError; end

  def initialize(integration:)
    @integration = integration
  end

  def publish!(board_key:, board_id:, initial_stage_id:, stages:)
    ensure_inactive!
    normalized_board_key = normalize_board_key!(board_key)
    board = find_board!(board_id)
    normalized_stages = normalize_stages!(board, stages)
    initial_stage = find_stage!(board, initial_stage_id, 'initial stage')
    persist_catalog!(normalized_board_key, board, initial_stage, normalized_stages)

    {
      'board_key' => normalized_board_key,
      'board_id' => board.id,
      'initial_stage_id' => initial_stage.id,
      'events' => normalized_stages.keys.sort
    }
  end

  private

  def ensure_inactive!
    raise InvalidCatalog, 'integration must be inactive while publishing the CRM catalog' if @integration.enabled?
  end

  def normalize_board_key!(board_key)
    normalized = board_key.to_s.strip
    raise InvalidCatalog, 'board_key is required' if normalized.blank?

    normalized
  end

  def find_board!(board_id)
    board = KanbanBoard.active.find_by(id: positive_integer(board_id), account_id: @integration.account_id)
    raise InvalidCatalog, 'board is not active in the integration account' if board.blank?

    board
  end

  def find_stage!(board, stage_id, label)
    stage = board.kanban_stages.active.find_by(id: positive_integer(stage_id))
    raise InvalidCatalog, "#{label} is not active on the selected board" if stage.blank?

    stage
  end

  def persist_catalog!(board_key, board, initial_stage, stages)
    settings = @integration.settings.deep_dup
    boards = (settings['crm'] ||= {})['boards'] ||= {}
    existing = boards[board_key] || {}
    validate_board_assignment!(existing, board)
    boards[board_key] = existing.merge(
      'board_id' => board.id,
      'initial_stage_id' => initial_stage.id,
      'stages' => stages
    )
    @integration.update!(settings: settings)
  end

  def validate_board_assignment!(existing, board)
    configured_board_id = positive_integer(existing['board_id'])
    return if configured_board_id.blank? || configured_board_id == board.id

    raise InvalidCatalog, 'board_key is already assigned to another board'
  end

  def normalize_stages!(board, stages)
    source = stages.respond_to?(:to_h) ? stages.to_h.deep_stringify_keys : {}
    raise InvalidCatalog, 'at least one semantic stage event is required' if source.empty?

    event_keys = source.keys
    source.to_h do |event_key, configuration|
      [event_key, normalize_stage!(board, event_key, configuration, event_keys)]
    end
  end

  def normalize_stage!(board, event_key, configuration, event_keys)
    raise InvalidCatalog, 'stage event key is invalid' unless event_key.match?(/\A[a-z][a-z0-9_]*\z/)

    stage = find_stage!(board, configuration['stage_id'], "stage for #{event_key}")
    allowed_from = Array(configuration['allowed_from']).map(&:to_s).map(&:strip).reject(&:blank?).uniq
    validate_allowed_from!(event_key, allowed_from, event_keys)
    { 'stage_id' => stage.id, 'allowed_from' => allowed_from }
  end

  def validate_allowed_from!(event_key, allowed_from, event_keys)
    return if allowed_from.all? { |source_key| event_keys.include?(source_key) }

    raise InvalidCatalog, "allowed_from for #{event_key} references an unpublished event"
  end

  def positive_integer(value)
    integer = Integer(value)
    integer.positive? ? integer : nil
  rescue ArgumentError, TypeError
    nil
  end
end
