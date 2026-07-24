class KanbanAutomations::WorkflowPreviewService
  MAX_NODES = 50
  NODE_HANDLERS = {
    'trigger' => :preview_trigger,
    'delay' => :preview_delay,
    'wait_until_field' => :preview_date_wait,
    'wait_for_response' => :preview_response_wait,
    'condition' => :preview_condition,
    'action' => :preview_action,
    'set_field' => :preview_action,
    'send_message' => :preview_message,
    'webhook' => :preview_webhook,
    'end' => :preview_end
  }.freeze

  def initialize(rule:, card:, now: Time.current)
    @rule = rule
    @card = card
    @now = now
  end

  def perform
    return [] unless rule.visual_flow?

    steps = []
    node_id = trigger_node.fetch('id')
    MAX_NODES.times do
      node = nodes.fetch(node_id)
      node_id = preview_node(node, steps)
      return steps if node_id.nil?
    end

    raise ArgumentError, 'Workflow preview exceeded the maximum number of nodes'
  end

  private

  attr_reader :rule, :card, :now

  def definition
    @definition ||= rule.flow_definition.to_h.deep_stringify_keys
  end

  def nodes
    @nodes ||= Array(definition['nodes']).index_by { |node| node.fetch('id') }
  end

  def trigger_node
    nodes.values.find { |node| node['type'] == 'trigger' } || raise(ArgumentError, 'Workflow requires a trigger node')
  end

  def preview_node(node, steps)
    handler = NODE_HANDLERS[node.fetch('type')] || raise(ArgumentError, "Workflow node #{node.fetch('type')} is not executable")
    send(handler, node, steps)
  end

  def preview_trigger(node, _steps)
    next_node_id(node)
  end

  def preview_delay(node, steps)
    steps << { 'node_id' => node.fetch('id'), 'type' => 'delay', 'scheduled_at' => (now + node.dig('data', 'delay_hours').to_f.hours).iso8601 }
    next_node_id(node)
  end

  def preview_date_wait(node, steps)
    steps << { 'node_id' => node.fetch('id'), 'type' => 'wait_until_field', 'field_key' => node.dig('data', 'field_key') }
    next_node_id(node)
  end

  def preview_response_wait(node, steps)
    steps << node.fetch('data', {}).slice('timeout_hours').merge('node_id' => node.fetch('id'), 'type' => 'wait_for_response')
    next_node_id(node)
  end

  def preview_condition(node, steps)
    branch = condition_matches?(node) ? 'yes' : 'no'
    steps << { 'node_id' => node.fetch('id'), 'type' => 'condition', 'branch' => branch }
    next_node_id(node, source_handle: branch)
  end

  def preview_action(node, steps)
    action_name = node['type'] == 'set_field' ? 'set_field' : node.dig('data', 'action_name')
    steps << node.fetch('data', {}).slice('action_params').merge(
      'node_id' => node.fetch('id'),
      'type' => 'action',
      'action_name' => action_name
    )
    next_node_id(node)
  end

  def preview_message(node, steps)
    steps << node.fetch('data', {}).slice('channel', 'content').merge('node_id' => node.fetch('id'), 'type' => 'send_message')
    next_node_id(node)
  end

  def preview_webhook(node, steps)
    steps << node.fetch('data', {}).slice('connection_id').merge('node_id' => node.fetch('id'), 'type' => 'webhook')
    next_node_id(node)
  end

  def preview_end(_node, _steps)
    nil
  end

  def condition_matches?(node)
    data = node.fetch('data', {}).deep_stringify_keys
    matches = condition_entries(data).map do |condition|
      KanbanAutomations::ConditionsMatcher.new(rule: rule, card: card).matches_field_condition?(condition)
    end

    data['match_mode'] == 'any' ? matches.any? : matches.all?
  end

  def condition_entries(data)
    entries = Array(data['conditions']).filter_map(&:presence)
    return entries if entries.present?

    [data.slice('field_key', 'operator', 'value')]
  end

  def next_node_id(node, source_handle: nil)
    edge = Array(definition['edges']).find do |item|
      item['source'] == node.fetch('id') && (source_handle.nil? || item['sourceHandle'].to_s == source_handle)
    end
    edge&.fetch('target') || raise(ArgumentError, "Workflow node #{node.fetch('id')} has no next node")
  end
end
