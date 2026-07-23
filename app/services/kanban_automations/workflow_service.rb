class KanbanAutomations::WorkflowService
  MAX_NODES_PER_EXECUTION = 50
  SYSTEM_DATE_FIELD_METHODS = {
    'system_starts_at' => :starts_at,
    'system_due_at' => :due_at,
    'system_next_action_at' => :next_action_at
  }.freeze
  NODE_HANDLERS = {
    'trigger' => :advance_node,
    'delay' => :delay_node,
    'wait_until_field' => :date_wait_node,
    'action' => :action_node,
    'send_message' => :message_node,
    'condition' => :condition_node,
    'end' => :end_node
  }.freeze

  def initialize(execution:, rule:, card:, now: Time.current)
    @execution = execution
    @rule = rule
    @card = card
    @now = now
  end

  def perform!
    node_id = workflow_state['next_node_id'] || trigger_node.fetch('id')
    results = Array(execution.action_results).dup

    MAX_NODES_PER_EXECUTION.times do
      node = nodes.fetch(node_id)
      node_id, outcome = execute_node(node, results)
      return outcome if outcome
    end

    raise ArgumentError, 'Workflow exceeded the maximum number of nodes per execution'
  end

  private

  attr_reader :execution, :rule, :card, :now

  def definition
    @definition ||= rule.flow_definition.to_h.deep_stringify_keys
  end

  def nodes
    @nodes ||= Array(definition['nodes']).index_by { |node| node.fetch('id') }
  end

  def workflow_state
    execution.workflow_state.to_h.deep_stringify_keys
  end

  def trigger_node
    nodes.values.find { |node| node['type'] == 'trigger' } || raise(ArgumentError, 'Workflow requires a trigger node')
  end

  def next_node_id(node, source_handle: nil)
    edge = Array(definition['edges']).find do |item|
      item['source'] == node.fetch('id') && (source_handle.nil? || item['sourceHandle'].to_s == source_handle)
    end
    edge&.fetch('target') || raise(ArgumentError, "Workflow node #{node.fetch('id')} has no next node")
  end

  def execute_node(node, results)
    handler = NODE_HANDLERS[node.fetch('type')] || raise(ArgumentError, "Workflow node #{node.fetch('type')} is not executable")
    send(handler, node, results)
  end

  def advance_node(node, _results)
    [next_node_id(node), nil]
  end

  def delay_node(node, results)
    [nil, wait_for_node(node, results)]
  end

  def date_wait_node(node, results)
    outcome = wait_until_field(node, results)
    outcome ? [nil, outcome] : [next_node_id(node), nil]
  end

  def action_node(node, results)
    results.concat(execute_action(node))
    [next_node_id(node), nil]
  end

  def message_node(node, results)
    result = send_message(node)
    return [nil, wait_for_message_node(node, results, result)] if result['status'] == 'waiting'

    results << result
    [next_node_id(node), nil]
  end

  def condition_node(node, results)
    branch = condition_matches?(node) ? 'yes' : 'no'
    results << { 'node_id' => node.fetch('id'), 'status' => 'succeeded', 'branch' => branch }
    [next_node_id(node, source_handle: branch), nil]
  end

  def end_node(_node, results)
    [nil, completed(results)]
  end

  def wait_for_node(node, results)
    delay_hours = node.fetch('data', {}).fetch('delay_hours').to_f
    raise ArgumentError, 'Workflow delay must be positive' unless delay_hours.positive?

    {
      status: :waiting,
      scheduled_at: now + delay_hours.hours,
      workflow_state: { 'next_node_id' => next_node_id(node) },
      action_results: results + [{ 'node_id' => node.fetch('id'), 'status' => 'waiting', 'delay_hours' => delay_hours }]
    }
  end

  def wait_until_field(node, results)
    data = node.fetch('data', {}).deep_stringify_keys
    scheduled_at = date_field_value(data.fetch('field_key')) + data.fetch('offset_hours').to_f.hours
    if scheduled_at <= now
      results << { 'node_id' => node.fetch('id'), 'status' => 'skipped', 'reason' => 'scheduled_time_in_past' }
      return nil
    end

    {
      status: :waiting,
      scheduled_at: scheduled_at,
      workflow_state: { 'next_node_id' => next_node_id(node) },
      action_results: results + [{ 'node_id' => node.fetch('id'), 'status' => 'waiting', 'scheduled_at' => scheduled_at.iso8601 }]
    }
  end

  def date_field_value(field_key)
    value = if field_key.start_with?('system_')
              card.public_send(SYSTEM_DATE_FIELD_METHODS.fetch(field_key))
            else
              card.custom_field_values.to_h[field_key]
            end
    return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

    Time.zone.parse(value.to_s) || raise(ArgumentError, "Workflow date field #{field_key} is blank or invalid")
  end

  def execute_action(node)
    data = node.fetch('data', {}).deep_stringify_keys
    action = {
      'action_name' => data.fetch('action_name'),
      'action_params' => data.fetch('action_params', {})
    }
    KanbanAutomations::ActionService.new(rule: rule, card: card, actions: [action]).perform!.map do |result|
      result.merge('node_id' => node.fetch('id'))
    end
  end

  def send_message(node)
    result = KanbanAutomations::WorkflowMessageService.new(card: card, data: node.fetch('data', {}), now: now).perform!
    result.merge('node_id' => node.fetch('id'))
  end

  def wait_for_message_node(node, results, result)
    scheduled_at = Time.zone.parse(result.fetch('scheduled_at'))
    {
      status: :waiting,
      scheduled_at: scheduled_at,
      workflow_state: { 'next_node_id' => node.fetch('id') },
      action_results: results + [result]
    }
  end

  def condition_matches?(node)
    data = node.fetch('data', {}).deep_stringify_keys
    condition = data.slice('field_key', 'operator', 'value')
    KanbanAutomations::ConditionsMatcher.new(rule: rule, card: card).matches_field_condition?(condition)
  end

  def completed(results)
    { status: :succeeded, scheduled_at: nil, workflow_state: {}, action_results: results }
  end
end
