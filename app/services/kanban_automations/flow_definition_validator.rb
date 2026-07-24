# rubocop:disable Metrics/ClassLength -- Node validations are intentionally centralized with the board reference checks.
class KanbanAutomations::FlowDefinitionValidator
  DATE_FIELD_TYPES = %w[date datetime].freeze
  ACTION_REFERENCE_VALIDATORS = {
    'move_stage' => :validate_action_stage,
    'assign_owner' => :validate_action_owner,
    'assign_round_robin' => :validate_action_round_robin,
    'set_field' => :validate_action_field,
    'increment_field' => :validate_action_field,
    'enroll_cadence' => :validate_action_cadence,
    'add_label' => :validate_action_label,
    'remove_label' => :validate_action_label,
    'add_note' => :validate_action_note
  }.freeze
  def initialize(rule:)
    @rule = rule
  end

  def validate
    return if definition[:nodes].blank? && definition[:edges].blank?

    validate_nodes
    validate_edges
    validate_node_data
  end

  private

  attr_reader :rule

  def definition
    @definition ||= rule.flow_definition.to_h.with_indifferent_access
  end

  def nodes
    @nodes ||= Array(definition[:nodes]).map { |node| node.to_h.with_indifferent_access }
  end

  def edges
    @edges ||= Array(definition[:edges]).map { |edge| edge.to_h.with_indifferent_access }
  end

  def node_ids
    @node_ids ||= nodes.pluck(:id).map(&:to_s)
  end

  def validate_nodes
    add_error('must have one trigger node') unless nodes.count { |node| node[:type] == 'trigger' } == 1
    add_error('node ids must be unique') unless node_ids.uniq.length == node_ids.length
    unsupported_types = nodes.pluck(:type).map(&:to_s) - KanbanAutomationRule::FLOW_NODE_TYPES
    add_error("unsupported node types: #{unsupported_types.join(', ')}") if unsupported_types.present?
  end

  def validate_edges
    invalid_edge = edges.any? do |edge|
      edge[:source].blank? || edge[:target].blank? || node_ids.exclude?(edge[:source].to_s) || node_ids.exclude?(edge[:target].to_s)
    end
    add_error('edges must connect existing nodes') if invalid_edge
    add_error('must not contain cycles') if workflow_has_cycle?
  end

  def workflow_has_cycle?
    visited = Set.new
    visiting = Set.new
    node_ids.any? { |node_id| cycle_from?(node_id, visited, visiting) }
  end

  def cycle_from?(node_id, visited, visiting)
    return false if visited.include?(node_id)
    return true if visiting.include?(node_id)

    visiting.add(node_id)
    outgoing_node_ids(node_id).any? { |target_id| cycle_from?(target_id, visited, visiting) }
  ensure
    visiting.delete(node_id)
    visited.add(node_id)
  end

  def outgoing_node_ids(node_id)
    edges.filter_map { |edge| edge[:target].to_s if edge[:source].to_s == node_id }
  end

  def validate_node_data
    nodes.each do |node|
      data = node[:data].to_h.with_indifferent_access
      validate_message_node(node, data)
      validate_delay_node(node, data)
      validate_wait_until_field_node(node, data)
      validate_wait_for_response_node(node, data)
      validate_wait_for_business_hours_node(node, data)
      validate_action_node(node, data)
      validate_condition_node(node, data)
      validate_round_robin_node(node, data)
      validate_webhook_node(node, data)
      validate_condition_paths(node)
      validate_round_robin_paths(node, data)
    end
  end

  def validate_message_node(node, data)
    return unless node[:type] == 'send_message'

    valid_channel = KanbanAppointmentReminderRule::CHANNELS.include?(data[:channel].to_s)
    valid_message = data[:content].present? && data[:opt_in_attribute_key].present?
    valid_policy = message_policy_valid?(data)
    valid_attachment = KanbanAutomations::MessageAttachmentService.new(data: data).valid?
    add_error("Message node #{node[:id]} is incomplete") unless valid_channel && valid_message && valid_policy && valid_attachment
  end

  def message_policy_valid?(data)
    frequency_limit_valid?(data[:frequency_limit_hours]) && quiet_hours_valid?(data[:quiet_hours])
  end

  def frequency_limit_valid?(value)
    return true if value.blank?

    value.to_f.positive? && value.to_f <= 24 * 30
  end

  def quiet_hours_valid?(value)
    source = value.to_h.with_indifferent_access
    return true if source.blank?
    return false unless source[:start].match?(/\A\d{2}:\d{2}\z/) && source[:end].match?(/\A\d{2}:\d{2}\z/)

    source[:start] != source[:end] && ActiveSupport::TimeZone[source[:timezone]].present?
  end

  def validate_delay_node(node, data)
    return unless node[:type] == 'delay'

    add_error("Delay node #{node[:id]} needs positive hours") unless data[:delay_hours].to_f.positive?
  end

  def validate_wait_until_field_node(node, data)
    return unless node[:type] == 'wait_until_field'

    valid_field = datetime_field?(data[:field_key])
    valid_offset = Float(data[:offset_hours])
    return if valid_field && valid_offset.finite?

    add_error("Date wait node #{node[:id]} is incomplete")
  rescue ArgumentError, TypeError
    add_error("Date wait node #{node[:id]} is incomplete")
  end

  def validate_wait_for_response_node(node, data)
    return unless node[:type] == 'wait_for_response'

    add_error("Response wait node #{node[:id]} needs positive timeout hours") unless data[:timeout_hours].to_f.positive?
  end

  def validate_wait_for_business_hours_node(node, data)
    return unless node[:type] == 'wait_for_business_hours'
    return if business_hours_valid?(data)

    add_error("Business hours node #{node[:id]} is incomplete")
  end

  def business_hours_valid?(data)
    weekdays = Array(data[:weekdays]).map { |day| Integer(day, exception: false) }
    valid_weekdays = weekdays.present? && weekdays.all? { |day| (1..7).cover?(day) }
    valid_times = business_times_valid?(data)
    valid_timezone = ActiveSupport::TimeZone[data[:timezone]].present?

    valid_weekdays && valid_times && valid_timezone
  end

  def business_times_valid?(data)
    valid_time?(data[:start_time]) && valid_time?(data[:end_time]) && data[:start_time] < data[:end_time]
  end

  def valid_time?(value)
    value.to_s.match?(/\A\d{2}:\d{2}\z/)
  end

  def validate_action_node(node, data)
    return unless %w[action set_field].include?(node[:type])

    action_name = node[:type] == 'set_field' ? 'set_field' : data[:action_name].to_s
    add_error("Action node #{node[:id]} has an unsupported action") unless KanbanAutomationRule::ACTION_NAMES.include?(action_name)
    validate_action_references(node, action_name, data[:action_params].to_h.with_indifferent_access)
  end

  def validate_condition_node(node, data)
    return unless node[:type] == 'condition'

    return if valid_condition_match_mode?(data) && condition_entries_valid?(data)

    add_error("Condition node #{node[:id]} is incomplete")
  end

  def valid_condition_match_mode?(data)
    %w[all any].include?(data[:match_mode].presence || 'all')
  end

  def condition_entries_valid?(data)
    entries = condition_entries(data)
    entries.present? && entries.all? { |condition| valid_condition_entry?(condition) }
  end

  def valid_condition_entry?(condition)
    condition_field_exists?(condition[:field_key]) && KanbanAutomationRule::FIELD_OPERATORS.include?(condition[:operator].to_s)
  end

  def condition_entries(data)
    entries = Array(data[:conditions]).filter_map do |condition|
      condition.to_h.with_indifferent_access.presence
    end
    return entries if entries.present?

    [data.slice(:field_key, :operator, :value)]
  end

  def validate_webhook_node(node, data)
    return unless node[:type] == 'webhook'

    connection = rule.kanban_board.kanban_automation_connections.active.find_by(id: data[:connection_id])
    add_error("Webhook node #{node[:id]} references an active connection on this board") if connection.blank?
  end

  def validate_round_robin_node(node, data)
    return unless node[:type] == 'round_robin'

    options = round_robin_options(data)
    valid_options = options.length >= 2 && options.all? { |option| option[:id].present? } && options.pluck(:id).uniq.length == options.length
    add_error("Round-robin node #{node[:id]} needs at least two options") unless valid_options
  end

  def validate_round_robin_paths(node, data)
    return unless node[:type] == 'round_robin'

    handles = edges.filter_map do |edge|
      edge[:sourceHandle].to_s if edge[:source].to_s == node[:id].to_s
    end
    expected = round_robin_options(data).pluck(:id).map(&:to_s).sort
    return if handles.sort == expected

    add_error("Round-robin node #{node[:id]} needs one path for every option")
  end

  def round_robin_options(data)
    Array(data[:options]).map { |option| option.to_h.with_indifferent_access }
  end

  def validate_condition_paths(node)
    return unless node[:type] == 'condition'

    handles = edges.filter_map do |edge|
      edge[:sourceHandle].to_s if edge[:source].to_s == node[:id].to_s
    end
    return if handles.tally.slice('yes', 'no') == { 'yes' => 1, 'no' => 1 }

    add_error("Condition node #{node[:id]} needs yes and no paths")
  end

  def condition_field_exists?(field_key)
    return true if KanbanCard::SYSTEM_CONDITION_VALUE_METHODS.key?(field_key.to_s)

    rule.kanban_board.configured_custom_field_definitions.any? { |field| field['key'] == field_key.to_s }
  end

  def datetime_field?(field_key)
    return %w[system_starts_at system_due_at system_next_action_at].include?(field_key.to_s) if field_key.to_s.start_with?('system_')

    rule.kanban_board.configured_custom_field_definitions.any? do |field|
      field['key'] == field_key.to_s && DATE_FIELD_TYPES.include?(field['field_type'])
    end
  end

  def validate_action_references(node, action_name, params)
    validator = ACTION_REFERENCE_VALIDATORS[action_name]
    send(validator, node, params) if validator
  end

  def validate_action_stage(node, params)
    return if rule.kanban_board.kanban_stages.exists?(id: params[:stage_id])

    add_error("Action node #{node[:id]} references a stage outside this board")
  end

  def validate_action_owner(node, params)
    return if params[:owner_id].blank? || rule.account.users.exists?(id: params[:owner_id])

    add_error("Action node #{node[:id]} references an agent outside this account")
  end

  def validate_action_round_robin(node, params)
    owner_ids = Array(params[:owner_ids]).filter_map { |value| Integer(value, exception: false) }
    valid_owners = owner_ids.present? && rule.account.users.where(id: owner_ids).count == owner_ids.uniq.count
    add_error("Action node #{node[:id]} needs valid round-robin owners") unless valid_owners
  end

  def validate_action_field(node, params)
    field = rule.kanban_board.configured_custom_field_definitions.find { |item| item['key'] == params[:field_key].to_s }
    return if field.present?

    add_error("Action node #{node[:id]} references a field outside this board")
  end

  def validate_action_cadence(node, params)
    return if rule.kanban_board.kanban_cadences.active.exists?(id: params[:cadence_id])

    add_error("Action node #{node[:id]} references a cadence outside this board")
  end

  def validate_action_label(node, params)
    return if params[:label].present?

    add_error("Action node #{node[:id]} needs a label")
  end

  def validate_action_note(node, params)
    return if params[:content].present?

    add_error("Action node #{node[:id]} needs note content")
  end

  def add_error(message)
    rule.errors.add(:flow_definition, message)
  end
end
# rubocop:enable Metrics/ClassLength
