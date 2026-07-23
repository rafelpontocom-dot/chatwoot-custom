class KanbanAutomations::ActionService
  ACTION_HANDLERS = {
    'move_stage' => :move_stage,
    'assign_owner' => :assign_owner,
    'set_next_action' => :update_next_action,
    'set_field' => :update_field,
    'increment_field' => :increment_field,
    'archive_card' => :archive_card,
    'enroll_cadence' => :enroll_cadence,
    'add_label' => :add_label,
    'remove_label' => :remove_label,
    'add_note' => :add_note
  }.freeze

  def initialize(rule:, card:, actions: nil)
    @rule = rule
    @card = card
    @board = rule.kanban_board
    @actions = actions
  end

  def perform!
    Array(@actions || @rule.actions).map do |action|
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

  def increment_field(params)
    field_key = params.fetch(:field_key).to_s
    definition = numeric_field_definition!(field_key)
    amount = increment_amount(params)
    next_value = incremented_field_value(field_key, amount, definition)
    @card.update!(custom_field_values: @card.custom_field_values.to_h.merge(field_key => next_value))
    result('increment_field', 'succeeded', field_key: field_key, amount: amount, value: next_value)
  end

  def numeric_field_definition!(field_key)
    definition = @board.configured_custom_field_definitions.find { |field| field['key'] == field_key }
    raise ActiveRecord::RecordNotFound, "Custom field #{field_key} was not found" if definition.blank?
    raise ArgumentError, "Custom field #{field_key} must be numeric" unless %w[integer decimal currency].include?(definition['field_type'])

    definition
  end

  def increment_amount(params)
    amount = Float(params.fetch(:amount, 1))
    raise ArgumentError, 'Increment amount cannot be zero' if amount.zero?

    amount
  rescue ArgumentError, TypeError
    raise ArgumentError, 'Increment amount must be numeric'
  end

  def incremented_field_value(field_key, amount, definition)
    value = Float(@card.custom_field_values.to_h[field_key].presence || 0) + amount
    definition['field_type'] == 'integer' && value.integer? ? value.to_i : value
  rescue ArgumentError, TypeError
    raise ArgumentError, "Custom field #{field_key} must have a numeric value"
  end

  def archive_card(_params)
    return result('archive_card', 'skipped') unless @card.active?

    @card.archive!
    result('archive_card', 'succeeded')
  end

  def enroll_cadence(params)
    cadence = @board.kanban_cadences.active.find(params.fetch(:cadence_id))
    existing = @card.kanban_cadence_enrollments.find_by(kanban_cadence: cadence)
    return result('enroll_cadence', 'skipped', cadence_id: cadence.id) if existing&.active? || existing&.awaiting_completion?

    KanbanCadences::EnrollService.new(card: @card, cadence: cadence, user: @card.owner).call
    result('enroll_cadence', 'succeeded', cadence_id: cadence.id)
  end

  def add_label(params)
    label = params.fetch(:label).to_s.strip
    raise ArgumentError, 'Label cannot be blank' if label.blank?

    @card.add_labels([label])
    result('add_label', 'succeeded', label: label)
  end

  def remove_label(params)
    label = params.fetch(:label).to_s.strip
    raise ArgumentError, 'Label cannot be blank' if label.blank?

    @card.label_list.remove(label)
    @card.save!
    result('remove_label', 'succeeded', label: label)
  end

  def add_note(params)
    content = params.fetch(:content).to_s.strip
    raise ArgumentError, 'Internal note cannot be blank' if content.blank?
    raise ArgumentError, 'Opportunity has no conversation for an internal note' if @card.conversation.blank?

    message = Messages::MessageBuilder.new(
      nil,
      @card.conversation,
      {
        content: content,
        message_type: 'outgoing',
        private: true
      }
    ).perform
    result('add_note', 'succeeded', message_id: message.id)
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
