# rubocop:disable Metrics/ClassLength -- This is the central registry for the supported commercial actions.
class KanbanAutomations::ActionService
  CONTACT_BOOLEAN_ATTRIBUTE_KEYS = %w[
    marketing_messages_opt_in
    birthday_messages_opt_in
    appointment_reminders_opt_in
  ].freeze
  CONTACT_DATE_ATTRIBUTE_KEYS = %w[date_of_birth].freeze

  ACTION_HANDLERS = {
    'move_stage' => :move_stage,
    'assign_owner' => :assign_owner,
    'assign_team' => :assign_team,
    'assign_round_robin' => :assign_round_robin,
    'set_next_action' => :update_next_action,
    'complete_next_action' => :complete_next_action,
    'mark_won' => :mark_won,
    'mark_lost' => :mark_lost,
    'set_field' => :update_field,
    'increment_field' => :increment_field,
    'clear_field' => :clear_field,
    'update_contact' => :update_contact,
    'archive_card' => :archive_card,
    'enroll_cadence' => :enroll_cadence,
    'add_label' => :add_label,
    'remove_label' => :remove_label,
    'add_contact_label' => :add_contact_label,
    'remove_contact_label' => :remove_contact_label,
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

  def assign_team(params)
    conversation = @card.conversation || raise(ActiveRecord::RecordNotFound, 'Conversation was not found for team assignment')
    team_id = params[:team_id].presence
    team = team_id && @rule.account.teams.find(team_id)
    conversation.update!(team: team)
    result('assign_team', 'succeeded', team_id: team&.id)
  end

  def assign_round_robin(params)
    @rule.with_lock do
      owner = next_round_robin_owner(params)
      if owner.blank?
        result('assign_round_robin', 'skipped', reason: 'no_available_owner')
      else
        @card.update!(owner: owner)
        @rule.update!(round_robin_cursor: @rule.round_robin_cursor + 1)
        result('assign_round_robin', 'succeeded', owner_id: owner.id)
      end
    end
  end

  def next_round_robin_owner(params)
    owner_ids = Array(params[:owner_ids]).filter_map { |owner_id| Integer(owner_id, exception: false) }
    raise ArgumentError, 'Round-robin needs at least one owner' if owner_ids.blank?

    owners = @rule.account.users.where(id: owner_ids).index_by(&:id)
    ordered_owners = owner_ids.filter_map { |owner_id| owners[owner_id] }
    raise ActiveRecord::RecordNotFound, 'Round-robin owner was not found' unless ordered_owners.length == owner_ids.length

    available_owners = eligible_round_robin_owners(ordered_owners, params[:availability_policy])
    return if available_owners.blank?

    available_owners[@rule.round_robin_cursor % available_owners.length]
  end

  def eligible_round_robin_owners(owners, availability_policy)
    policy = availability_policy.presence || 'any'
    return owners if policy == 'any'

    allowed_statuses = policy == 'online_only' ? ['online'] : %w[online busy]
    statuses = OnlineStatusTracker.get_available_users(@rule.account.id).to_h
    owners.select { |owner| allowed_statuses.include?(statuses[owner.id.to_s]) }
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

  def complete_next_action(params)
    return result('complete_next_action', 'skipped') if @card.next_action_at.blank? || @card.next_action_completed_at.present?

    follow_up_attributes = follow_up_action_attributes(params)
    @card.transaction do
      @card.next_action_completion_note = params[:completion_note].to_s.strip.presence
      @card.update!(next_action_completed_at: Time.current)
      @card.update!(follow_up_attributes) if follow_up_attributes.present?
      result('complete_next_action', 'succeeded', next_action_at: follow_up_attributes&.fetch(:next_action_at)&.iso8601)
    end
  end

  def follow_up_action_attributes(params)
    return if params[:schedule_next_action] == false
    return unless params[:next_action_type].present? || params[:next_action_at].present?

    raise ArgumentError, 'Next action type and date are required together' if params[:next_action_type].blank? || params[:next_action_at].blank?

    {
      next_action_type: params[:next_action_type],
      next_action_at: parse_time(params[:next_action_at]),
      next_action_note: params[:next_action_note]
    }
  end

  def mark_won(_params)
    @card.update!(won_at: Time.current, lost_at: nil, lost_reason: nil, closed_by: @card.owner)
    result('mark_won', 'succeeded')
  end

  def mark_lost(params)
    reason = params.fetch(:lost_reason).to_s.strip
    raise ArgumentError, 'Lost reason must be configured for this board' unless @board.configured_lost_reason_options.include?(reason)

    @card.update!(won_at: nil, lost_at: Time.current, lost_reason: reason, closed_by: @card.owner)
    result('mark_lost', 'succeeded', lost_reason: reason)
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

  def clear_field(params)
    field_key = params.fetch(:field_key).to_s
    configured_field_definition!(field_key)
    @card.update!(custom_field_values: @card.custom_field_values.to_h.except(field_key))
    result('clear_field', 'succeeded', field_key: field_key)
  end

  def update_contact(params)
    attribute_key = params.fetch(:attribute_key).to_s
    raise ArgumentError, 'Contact attribute key is not allowed' unless safe_contact_attribute_key?(attribute_key)

    attributes = @card.contact.custom_attributes.to_h.merge(attribute_key => normalized_contact_attribute_value(attribute_key, params[:value]))
    @card.contact.update!(custom_attributes: attributes)
    result('update_contact', 'succeeded', attribute_key: attribute_key)
  end

  def safe_contact_attribute_key?(attribute_key)
    attribute_key.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/) && Contact.column_names.exclude?(attribute_key)
  end

  def normalized_contact_attribute_value(attribute_key, value)
    return normalized_contact_boolean(value) if CONTACT_BOOLEAN_ATTRIBUTE_KEYS.include?(attribute_key)
    return Date.iso8601(value.to_s).iso8601 if CONTACT_DATE_ATTRIBUTE_KEYS.include?(attribute_key)

    value
  rescue Date::Error
    raise ArgumentError, 'Contact date value must be a valid ISO date'
  end

  def normalized_contact_boolean(value)
    return true if value == true || %w[true 1].include?(value.to_s)
    return false if value == false || %w[false 0].include?(value.to_s)

    raise ArgumentError, 'Contact consent value must be true or false'
  end

  def numeric_field_definition!(field_key)
    definition = configured_field_definition!(field_key)
    raise ArgumentError, "Custom field #{field_key} must be numeric" unless %w[integer decimal currency].include?(definition['field_type'])

    definition
  end

  def configured_field_definition!(field_key)
    definition = @board.configured_custom_field_definitions.find { |field| field['key'] == field_key }
    raise ActiveRecord::RecordNotFound, "Custom field #{field_key} was not found" if definition.blank?

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

  def add_contact_label(params)
    label = contact_label!(params)
    @card.contact.add_labels([label])
    result('add_contact_label', 'succeeded', label: label)
  end

  def remove_contact_label(params)
    label = contact_label!(params)
    @card.contact.label_list.remove(label)
    @card.contact.save!
    result('remove_contact_label', 'succeeded', label: label)
  end

  def contact_label!(params)
    label = params.fetch(:label).to_s.strip
    raise ArgumentError, 'Label cannot be blank' if label.blank?

    label
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
    Time.zone.parse(value.to_s) || raise(ArgumentError)
  rescue ArgumentError, TypeError
    raise ArgumentError, 'next_action_at is invalid'
  end

  def result(action_name, status, details = {})
    { 'action_name' => action_name, 'status' => status }.merge(details.stringify_keys)
  end
end
# rubocop:enable Metrics/ClassLength
