class KanbanAutomations::ActionService
  ACTION_HANDLERS = {
    'move_stage' => :move_stage,
    'assign_owner' => :assign_owner,
    'set_next_action' => :update_next_action,
    'set_field' => :update_field,
    'archive_card' => :archive_card
  }.freeze

  def initialize(rule:, card:)
    @rule = rule
    @card = card
    @board = rule.kanban_board
  end

  def perform!
    Array(@rule.actions).map do |action|
      source = action.to_h.with_indifferent_access
      action_name = source[:action_name].to_s
      params = source[:action_params].to_h.with_indifferent_access
      send(ACTION_HANDLERS.fetch(action_name), params)
    end
  end

  private

  def move_stage(params)
    stage = @board.kanban_stages.active.find(params.fetch(:stage_id))
    return result('move_stage', 'skipped') if @card.kanban_stage_id == stage.id

    position = @board.kanban_cards.active.where(kanban_stage: stage).maximum(:position).to_i + 1
    @card.reorder_to_position!(kanban_stage: stage, position: position)
    result('move_stage', 'succeeded', stage_id: stage.id)
  end

  def assign_owner(params)
    owner_id = params[:owner_id].presence
    owner = owner_id && @rule.account.users.find(owner_id)
    @card.update!(owner: owner)
    result('assign_owner', 'succeeded', owner_id: owner&.id)
  end

  def update_next_action(params)
    next_action_at = parse_time(params[:next_action_at]) if params[:next_action_at].present?
    @card.update!(
      next_action_type: params[:next_action_type],
      next_action_at: next_action_at,
      next_action_note: params[:next_action_note]
    )
    result('set_next_action', 'succeeded', next_action_at: next_action_at&.iso8601)
  end

  def update_field(params)
    field_key = params.fetch(:field_key).to_s
    definition = @board.configured_custom_field_definitions.find { |field| field['key'] == field_key }
    raise ActiveRecord::RecordNotFound, "Custom field #{field_key} was not found" if definition.blank?

    values = @card.custom_field_values.to_h.merge(field_key => params[:value])
    @card.update!(custom_field_values: values)
    result('set_field', 'succeeded', field_key: field_key)
  end

  def archive_card(_params)
    return result('archive_card', 'skipped') unless @card.active?

    @card.archive!
    result('archive_card', 'succeeded')
  end

  def parse_time(value)
    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    raise ActiveRecord::RecordInvalid, 'next_action_at is invalid'
  end

  def result(action_name, status, details = {})
    { 'action_name' => action_name, 'status' => status }.merge(details.stringify_keys)
  end
end
