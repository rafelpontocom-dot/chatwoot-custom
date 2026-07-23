class KanbanAutomations::FlowDefinitionValidator
  DATE_FIELD_TYPES = %w[date datetime].freeze
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
      validate_action_node(node, data)
      validate_condition_node(node, data)
      validate_condition_paths(node)
    end
  end

  def validate_message_node(node, data)
    return unless node[:type] == 'send_message'

    valid_channel = KanbanAppointmentReminderRule::CHANNELS.include?(data[:channel].to_s)
    valid_message = data[:content].present? && data[:opt_in_attribute_key].present?
    valid_policy = message_policy_valid?(data)
    add_error("Message node #{node[:id]} is incomplete") unless valid_channel && valid_message && valid_policy
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

  def validate_action_node(node, data)
    return unless node[:type] == 'action'

    action_name = data[:action_name].to_s
    add_error("Action node #{node[:id]} has an unsupported action") unless KanbanAutomationRule::ACTION_NAMES.include?(action_name)
    validate_action_references(node, action_name, data[:action_params].to_h.with_indifferent_access)
  end

  def validate_condition_node(node, data)
    return unless node[:type] == 'condition'

    valid_field = condition_field_exists?(data[:field_key])
    valid_operator = KanbanAutomationRule::FIELD_OPERATORS.include?(data[:operator].to_s)
    return if valid_field && valid_operator

    add_error("Condition node #{node[:id]} is incomplete")
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
    validate_action_stage(node, params) if action_name == 'move_stage'
    validate_action_owner(node, params) if action_name == 'assign_owner'
    validate_action_field(node, params) if action_name == 'set_field'
    validate_action_cadence(node, params) if action_name == 'enroll_cadence'
  end

  def validate_action_stage(node, params)
    return if rule.kanban_board.kanban_stages.exists?(id: params[:stage_id])

    add_error("Action node #{node[:id]} references a stage outside this board")
  end

  def validate_action_owner(node, params)
    return if params[:owner_id].blank? || rule.account.users.exists?(id: params[:owner_id])

    add_error("Action node #{node[:id]} references an agent outside this account")
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

  def add_error(message)
    rule.errors.add(:flow_definition, message)
  end
end
