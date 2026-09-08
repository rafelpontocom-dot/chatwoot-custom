class RaevoAi::CrmCatalogPublisher
  class InvalidCatalog < StandardError; end

  def initialize(integration:)
    @integration = integration
  end

  def publish!(board_key:, board_id:, initial_stage_id:, stages:)
    raise InvalidCatalog, 'integration must be inactive while publishing the CRM catalog' if @integration.enabled?

    normalized_board_key = board_key.to_s.strip
    raise InvalidCatalog, 'board_key is required' if normalized_board_key.blank?

    board = KanbanBoard.active.find_by(id: positive_integer(board_id), account_id: @integration.account_id)
    raise InvalidCatalog, 'board is not active in the integration account' if board.blank?

    normalized_stages = normalize_stages!(board, stages)
    initial_stage = board.kanban_stages.active.find_by(id: positive_integer(initial_stage_id))
    raise InvalidCatalog, 'initial stage is not active on the selected board' if initial_stage.blank?

    settings = @integration.settings.deep_dup
    crm = settings['crm'] ||= {}
    boards = crm['boards'] ||= {}
    existing = boards[normalized_board_key] || {}
    configured_board_id = positive_integer(existing['board_id'])
    raise InvalidCatalog, 'board_key is already assigned to another board' if configured_board_id.present? && configured_board_id != board.id

    boards[normalized_board_key] = existing.merge(
      'board_id' => board.id,
      'initial_stage_id' => initial_stage.id,
      'stages' => normalized_stages
    )
    @integration.update!(settings: settings)

    {
      'board_key' => normalized_board_key,
      'board_id' => board.id,
      'initial_stage_id' => initial_stage.id,
      'events' => normalized_stages.keys.sort
    }
  end

  private

  def normalize_stages!(board, stages)
    source = stages.respond_to?(:to_h) ? stages.to_h.deep_stringify_keys : {}
    raise InvalidCatalog, 'at least one semantic stage event is required' if source.empty?

    event_keys = source.keys
    source.to_h do |event_key, configuration|
      raise InvalidCatalog, 'stage event key is invalid' unless event_key.match?(/\A[a-z][a-z0-9_]*\z/)

      stage = board.kanban_stages.active.find_by(id: positive_integer(configuration['stage_id']))
      raise InvalidCatalog, "stage for #{event_key} is not active on the selected board" if stage.blank?

      allowed_from = Array(configuration['allowed_from']).map(&:to_s).map(&:strip).reject(&:blank?).uniq
      unless allowed_from.all? { |source_key| event_keys.include?(source_key) }
        raise InvalidCatalog, "allowed_from for #{event_key} references an unpublished event"
      end

      [event_key, { 'stage_id' => stage.id, 'allowed_from' => allowed_from }]
    end
  end

  def positive_integer(value)
    integer = Integer(value)
    integer.positive? ? integer : nil
  rescue ArgumentError, TypeError
    nil
  end
end
