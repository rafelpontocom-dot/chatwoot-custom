# rubocop:disable Metrics/ClassLength -- Preview handlers stay together to mirror the executable workflow contract.
class KanbanAutomations::WorkflowPreviewService
  MAX_NODES = 50
  SYSTEM_DATE_FIELD_METHODS = {
    'system_starts_at' => :starts_at,
    'system_due_at' => :due_at,
    'system_next_action_at' => :next_action_at
  }.freeze
  NODE_HANDLERS = {
    'trigger' => :preview_trigger,
    'delay' => :preview_delay,
    'wait_until_field' => :preview_date_wait,
    'wait_for_response' => :preview_response_wait,
    'wait_for_inactivity' => :preview_inactivity_wait,
    'wait_for_business_hours' => :preview_business_hours,
    'condition' => :preview_condition,
    'filter' => :preview_filter,
    'message_eligibility' => :preview_message_eligibility,
    'round_robin' => :preview_round_robin,
    'human_handoff' => :preview_human_handoff,
    'audit_log' => :preview_audit_log,
    'action' => :preview_action,
    'set_field' => :preview_action,
    'update_contact' => :preview_action,
    'complete_next_action' => :preview_action,
    'mark_won' => :preview_action,
    'mark_lost' => :preview_action,
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
    data = node.fetch('data', {}).deep_stringify_keys
    scheduled_at = preview_date_wait_time(data)
    steps << {
      'node_id' => node.fetch('id'),
      'type' => 'wait_until_field',
      'field_key' => data['field_key'],
      'scheduled_at' => scheduled_at.iso8601,
      'status' => scheduled_at <= now ? 'skipped' : 'waiting',
      'reason' => scheduled_at <= now ? 'scheduled_time_in_past' : nil
    }.compact
    next_node_id(node)
  end

  def preview_date_wait_time(data)
    preview_date_field_value(data.fetch('field_key'), data['timezone']) + data.fetch('offset_hours').to_f.hours
  end

  def preview_date_field_value(field_key, timezone_name)
    value = if field_key.start_with?('system_')
              card.public_send(SYSTEM_DATE_FIELD_METHODS.fetch(field_key))
            else
              card.custom_field_values.to_h[field_key]
            end
    timezone = timezone_name.present? ? Time.find_zone!(timezone_name) : Time.zone
    return value.in_time_zone(timezone) if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

    timezone.parse(value.to_s) || raise(ArgumentError, "Workflow date field #{field_key} is blank or invalid")
  end

  def preview_response_wait(node, steps)
    steps << node.fetch('data', {}).slice('timeout_hours').merge('node_id' => node.fetch('id'), 'type' => 'wait_for_response')
    next_node_id(node)
  end

  def preview_inactivity_wait(node, steps)
    steps << node.fetch('data', {}).slice('timeout_hours').merge('node_id' => node.fetch('id'), 'type' => 'wait_for_inactivity')
    next_node_id(node)
  end

  def preview_business_hours(node, steps)
    steps << node.fetch('data', {}).slice('weekdays', 'start_time', 'end_time', 'timezone').merge(
      'node_id' => node.fetch('id'),
      'type' => 'wait_for_business_hours'
    )
    next_node_id(node)
  end

  def preview_condition(node, steps)
    branch = matching_condition_branch(node)
    steps << { 'node_id' => node.fetch('id'), 'type' => 'condition', 'branch' => branch }
    next_node_id(node, source_handle: branch)
  end

  def preview_filter(node, steps)
    matched = condition_matches?(node.fetch('data', {}).deep_stringify_keys)
    steps << { 'node_id' => node.fetch('id'), 'type' => 'filter', 'matched' => matched }
    matched ? next_node_id(node) : nil
  end

  def preview_message_eligibility(node, steps)
    result = KanbanAutomations::WorkflowMessageService.new(card: card, data: node.fetch('data', {}), now: now).eligibility
    branch = result['status'] == 'eligible' ? 'eligible' : 'otherwise'
    steps << result.except('conversation').merge('node_id' => node.fetch('id'), 'type' => 'message_eligibility', 'branch' => branch)
    next_node_id(node, source_handle: branch)
  end

  def preview_human_handoff(node, steps)
    steps << node.fetch('data', {}).slice('team_id', 'owner_id', 'note').merge('node_id' => node.fetch('id'), 'type' => 'human_handoff')
    nil
  end

  def preview_audit_log(node, steps)
    steps << node.fetch('data', {}).slice('content').merge('node_id' => node.fetch('id'), 'type' => 'audit_log')
    next_node_id(node)
  end

  def preview_round_robin(node, steps)
    option = Array(node.dig('data', 'options')).first || {}
    steps << { 'node_id' => node.fetch('id'), 'type' => 'round_robin', 'option_id' => option['id'] }
    next_node_id(node, source_handle: option.fetch('id'))
  end

  def preview_action(node, steps)
    action_name = if %w[set_field update_contact complete_next_action mark_won mark_lost].include?(node['type'])
                    node['type']
                  else
                    node.dig('data', 'action_name')
                  end
    steps << node.fetch('data', {}).slice('action_params').merge(
      'node_id' => node.fetch('id'),
      'type' => 'action',
      'action_name' => action_name
    )
    next_node_id(node)
  end

  def preview_message(node, steps)
    data = node.fetch('data', {})
    steps << data.slice('channel').merge(
      'node_id' => node.fetch('id'),
      'type' => 'send_message',
      'rendered_content' => KanbanAutomations::WorkflowMessageService.new(card: card, data: data, now: now).preview_content
    )
    next_node_id(node)
  end

  def preview_webhook(node, steps)
    connection = rule.kanban_board.kanban_automation_connections.active.find_by(
      id: node.dig('data', 'connection_id')
    )
    steps << {
      'node_id' => node.fetch('id'),
      'type' => 'webhook',
      'connection_name' => connection&.name
    }
    next_node_id(node)
  end

  def preview_end(_node, _steps)
    nil
  end

  def matching_condition_branch(node)
    data = node.fetch('data', {}).deep_stringify_keys
    branches = Array(data['branches']).filter_map(&:presence)
    return condition_matches?(data) ? 'yes' : 'no' if branches.blank?

    branches.each do |branch|
      return branch.fetch('id') if condition_matches?(branch.deep_stringify_keys)
    end

    data.fetch('fallback_id', 'otherwise')
  end

  def condition_matches?(data)
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
# rubocop:enable Metrics/ClassLength
