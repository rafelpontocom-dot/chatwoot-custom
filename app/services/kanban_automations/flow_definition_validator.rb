class KanbanAutomations::FlowDefinitionValidator
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
  end

  def validate_node_data
    nodes.each do |node|
      data = node[:data].to_h.with_indifferent_access
      validate_message_node(node, data)
      validate_delay_node(node, data)
      validate_action_node(node, data)
    end
  end

  def validate_message_node(node, data)
    return unless node[:type] == 'send_message'

    valid_channel = KanbanAppointmentReminderRule::CHANNELS.include?(data[:channel].to_s)
    valid_message = data[:content].present? && data[:opt_in_attribute_key].present?
    add_error("Message node #{node[:id]} is incomplete") unless valid_channel && valid_message
  end

  def validate_delay_node(node, data)
    return unless node[:type] == 'delay'

    add_error("Delay node #{node[:id]} needs positive hours") unless data[:delay_hours].to_f.positive?
  end

  def validate_action_node(node, data)
    return unless node[:type] == 'action'

    action_name = data[:action_name].to_s
    add_error("Action node #{node[:id]} has an unsupported action") unless KanbanAutomationRule::ACTION_NAMES.include?(action_name)
    validate_action_references(node, action_name, data[:action_params].to_h.with_indifferent_access)
  end

  def validate_action_references(node, action_name, params)
    validate_action_stage(node, params) if action_name == 'move_stage'
    validate_action_owner(node, params) if action_name == 'assign_owner'
    validate_action_field(node, params) if action_name == 'set_field'
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

  def add_error(message)
    rule.errors.add(:flow_definition, message)
  end
end
