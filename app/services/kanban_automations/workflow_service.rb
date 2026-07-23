class KanbanAutomations::WorkflowService
  MAX_NODES_PER_EXECUTION = 50

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

  def next_node_id(node)
    edge = Array(definition['edges']).find { |item| item['source'] == node.fetch('id') }
    edge&.fetch('target') || raise(ArgumentError, "Workflow node #{node.fetch('id')} has no next node")
  end

  def execute_node(node, results)
    case node.fetch('type')
    when 'trigger' then [next_node_id(node), nil]
    when 'delay' then [nil, wait_for_node(node, results)]
    when 'action'
      results.concat(execute_action(node))
      [next_node_id(node), nil]
    when 'send_message'
      results << send_message(node)
      [next_node_id(node), nil]
    when 'end' then [nil, completed(results)]
    else raise ArgumentError, "Workflow node #{node.fetch('type')} is not executable"
    end
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
    result = KanbanAutomations::WorkflowMessageService.new(card: card, data: node.fetch('data', {})).perform!
    result.merge('node_id' => node.fetch('id'))
  end

  def completed(results)
    { status: :succeeded, scheduled_at: nil, workflow_state: {}, action_results: results }
  end
end
