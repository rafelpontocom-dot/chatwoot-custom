# rubocop:disable Metrics/ClassLength -- Node handlers share the same execution state and transaction boundary.
class KanbanAutomations::WorkflowService
  MAX_NODES_PER_EXECUTION = 50
  SYSTEM_DATE_FIELD_METHODS = {
    'system_starts_at' => :starts_at,
    'system_due_at' => :due_at,
    'system_next_action_at' => :next_action_at,
    'system_appointment_starts_at' => :appointment_starts_at
  }.freeze
  NODE_HANDLERS = {
    'trigger' => :advance_node,
    'delay' => :delay_node,
    'random_delay' => :random_delay_node,
    'wait_until_field' => :date_wait_node,
    'wait_for_response' => :response_wait_node,
    'wait_for_inactivity' => :inactivity_wait_node,
    'wait_for_business_hours' => :business_hours_node,
    'stage_guard' => :stage_guard_node,
    'action' => :action_node,
    'set_field' => :action_node,
    'update_contact' => :action_node,
    'complete_next_action' => :action_node,
    'mark_won' => :action_node,
    'mark_lost' => :action_node,
    'send_message' => :message_node,
    'condition' => :condition_node,
    'filter' => :filter_node,
    'duplicate_check' => :duplicate_check_node,
    'message_eligibility' => :message_eligibility_node,
    'round_robin' => :round_robin_node,
    'human_handoff' => :human_handoff_node,
    'notify_team' => :notify_team_node,
    'create_opportunity' => :create_opportunity_node,
    'audit_log' => :audit_log_node,
    'webhook' => :webhook_node,
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
      results_count = results.length
      node = nodes.fetch(node_id)
      node_id, outcome = execute_node(node, results)
      return stamp_outcome(outcome, results_count) if outcome

      stamp_results(results, results_count)
    end

    raise ArgumentError, 'Workflow exceeded the maximum number of nodes per execution'
  end

  private

  attr_reader :execution, :rule, :card, :now

  def definition
    flow_definition = execution.automation_snapshot.to_h['flow_definition'].presence || rule.flow_definition
    @definition ||= flow_definition.to_h.deep_stringify_keys
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

  def random_delay_node(node, results)
    [nil, wait_for_random_node(node, results)]
  end

  def date_wait_node(node, results)
    outcome = wait_until_field(node, results)
    outcome ? [nil, outcome] : [next_date_wait_node_id(node), nil]
  rescue ArgumentError
    raise unless node.dig('data', 'failure_mode') == 'route'

    results << { 'node_id' => node.fetch('id'), 'status' => 'failed', 'reason' => 'date_field_unavailable' }
    [next_node_id(node, source_handle: 'failed'), nil]
  end

  def next_date_wait_node_id(node)
    handle = node.dig('data', 'failure_mode') == 'route' ? 'succeeded' : nil
    next_node_id(node, source_handle: handle)
  end

  def response_wait_node(node, results)
    timeout_hours = node.fetch('data', {}).fetch('timeout_hours').to_f
    raise ArgumentError, 'Workflow response timeout must be positive' unless timeout_hours.positive?

    [
      nil,
      {
        status: :waiting,
        scheduled_at: now + timeout_hours.hours,
        workflow_state: response_wait_state(node),
        action_results: results + [
          {
            'node_id' => node.fetch('id'),
            'status' => 'waiting',
            'timeout_hours' => timeout_hours,
            'waiting_for' => 'customer_message'
          }
        ]
      }
    ]
  end

  def response_wait_state(node)
    state = {
      'next_node_id' => next_response_wait_node_id(node, 'received'),
      'waiting_for' => 'customer_message'
    }
    state['timeout_node_id'] = next_response_wait_node_id(node, 'timeout') if node.dig('data', 'timeout_mode') == 'route'
    state
  end

  def next_response_wait_node_id(node, source_handle)
    handle = node.dig('data', 'timeout_mode') == 'route' ? source_handle : nil
    next_node_id(node, source_handle: handle)
  end

  def inactivity_wait_node(node, results)
    timeout_hours = node.fetch('data', {}).fetch('timeout_hours').to_f
    raise ArgumentError, 'Workflow inactivity timeout must be positive' unless timeout_hours.positive?

    [nil, inactivity_wait_result(node, results, timeout_hours)]
  end

  def inactivity_wait_result(node, results, timeout_hours)
    {
      status: :waiting,
      scheduled_at: now + timeout_hours.hours,
      workflow_state: inactivity_wait_state(node),
      action_results: results + [
        {
          'node_id' => node.fetch('id'),
          'status' => 'waiting',
          'timeout_hours' => timeout_hours,
          'waiting_for' => 'customer_inactivity'
        }
      ]
    }
  end

  def inactivity_wait_state(node)
    state = {
      'next_node_id' => next_inactivity_wait_node_id(node, 'inactive'),
      'waiting_for' => 'customer_inactivity'
    }
    state['response_node_id'] = next_inactivity_wait_node_id(node, 'responded') if node.dig('data', 'interruption_mode') == 'route'
    state
  end

  def next_inactivity_wait_node_id(node, source_handle)
    handle = node.dig('data', 'interruption_mode') == 'route' ? source_handle : nil
    next_node_id(node, source_handle: handle)
  end

  def business_hours_node(node, results)
    scheduled_at = next_business_time(node.fetch('data', {}).deep_stringify_keys)
    return [next_business_hours_node_id(node), nil] if scheduled_at.blank?

    [nil, business_hours_wait_result(node, results, scheduled_at)]
  rescue ArgumentError
    raise unless node.dig('data', 'failure_mode') == 'route'

    results << { 'node_id' => node.fetch('id'), 'status' => 'failed', 'reason' => 'business_hours_unavailable' }
    [next_node_id(node, source_handle: 'failed'), nil]
  end

  def stage_guard_node(node, results)
    stage_ids = Array(rule.trigger_conditions[:stage_ids]).map(&:to_i)
    if stage_ids.include?(card.kanban_stage_id)
      results << { 'node_id' => node.fetch('id'), 'status' => 'succeeded' }
      [next_node_id(node), nil]
    else
      result = { 'node_id' => node.fetch('id'), 'status' => 'skipped', 'reason' => 'stage_changed' }
      [nil, completed(results + [result])]
    end
  end

  def business_hours_wait_result(node, results, scheduled_at)
    {
      status: :waiting,
      scheduled_at: scheduled_at,
      workflow_state: { 'next_node_id' => next_business_hours_node_id(node) },
      action_results: results + [
        {
          'node_id' => node.fetch('id'),
          'status' => 'waiting',
          'reason' => 'outside_business_hours',
          'scheduled_at' => scheduled_at.iso8601
        }
      ]
    }
  end

  def next_business_hours_node_id(node)
    handle = node.dig('data', 'failure_mode') == 'route' ? 'succeeded' : nil
    next_node_id(node, source_handle: handle)
  end

  def action_node(node, results)
    results.concat(execute_action(node))
    [next_node_id(node), nil]
  end

  def message_node(node, results)
    result = send_message(node)
    return [nil, wait_for_message_node(node, results, result)] if result['status'] == 'waiting'

    results << result
    [next_message_node_id(node, result), nil]
  end

  def next_message_node_id(node, result)
    return next_node_id(node) unless node.dig('data', 'failure_mode') == 'route'

    handle = result['status'] == 'succeeded' ? 'succeeded' : 'failed'
    next_node_id(node, source_handle: handle)
  end

  def condition_node(node, results)
    branch = matching_condition_branch(node)
    results << { 'node_id' => node.fetch('id'), 'status' => 'succeeded', 'branch' => branch }
    [next_node_id(node, source_handle: branch), nil]
  end

  def filter_node(node, results)
    if condition_matches?(node.fetch('data', {}).deep_stringify_keys)
      results << { 'node_id' => node.fetch('id'), 'status' => 'succeeded' }
      return [next_node_id(node), nil]
    end

    results << {
      'node_id' => node.fetch('id'),
      'status' => 'skipped',
      'reason' => 'filter_not_matched'
    }
    [nil, completed(results)]
  end

  def duplicate_check_node(node, results)
    duplicate_card_ids = duplicate_cards.pluck(:id)
    branch = duplicate_card_ids.present? ? 'duplicate' : 'unique'
    results << {
      'node_id' => node.fetch('id'),
      'status' => 'succeeded',
      'branch' => branch,
      'duplicate_card_ids' => duplicate_card_ids
    }
    [next_node_id(node, source_handle: branch), nil]
  end

  def duplicate_cards
    rule.kanban_board.kanban_cards.active.where(contact: card.contact).where.not(id: card.id)
  end

  def message_eligibility_node(node, results)
    data = node.fetch('data', {})
    result = KanbanAutomations::WorkflowMessageService.new(card: card, data: data, now: now).eligibility
    branch = result['status'] == 'eligible' ? 'eligible' : 'otherwise'
    results << result.merge('node_id' => node.fetch('id'), 'branch' => branch).except('conversation')
    [next_node_id(node, source_handle: branch), nil]
  end

  def round_robin_node(node, results)
    option = next_round_robin_option(node)
    results << {
      'node_id' => node.fetch('id'),
      'status' => 'succeeded',
      'option_id' => option.fetch('id')
    }
    [next_node_id(node, source_handle: option.fetch('id')), nil]
  end

  def human_handoff_node(node, results)
    data = node.fetch('data', {}).deep_stringify_keys
    action_results = KanbanAutomations::ActionService.new(rule: rule, card: card, actions: human_handoff_actions(data)).perform!
    results.concat(action_results.map { |result| result.merge('node_id' => node.fetch('id')) })
    [nil, completed(results)]
  end

  def human_handoff_actions(data)
    [
      handoff_action('assign_team', 'team_id', data),
      handoff_action('assign_owner', 'owner_id', data),
      handoff_action('add_note', 'note', data, parameter: 'content')
    ].compact
  end

  def handoff_action(action_name, data_key, data, parameter: data_key)
    return if data[data_key].blank?

    { 'action_name' => action_name, 'action_params' => { parameter => data.fetch(data_key) } }
  end

  def notify_team_node(node, results)
    unless card.conversation
      results << { 'node_id' => node.fetch('id'), 'status' => 'skipped', 'reason' => 'no_linked_conversation' }
      return [next_node_id(node), nil]
    end

    message, teams = create_team_notification(node)
    results << team_notification_result(node, message, teams)
    [next_node_id(node), nil]
  end

  def create_team_notification(node)
    data = node.fetch('data', {}).deep_stringify_keys
    teams = notification_teams!(data.fetch('team_ids', []))
    message = Messages::MessageBuilder.new(nil, card.conversation, notification_message_attributes(data, teams)).perform
    [message, teams]
  end

  def notification_message_attributes(data, teams)
    {
      content: notification_content(data.fetch('content'), teams),
      message_type: 'outgoing',
      private: true
    }
  end

  def team_notification_result(node, message, teams)
    {
      'node_id' => node.fetch('id'),
      'status' => 'succeeded',
      'message_id' => message.id,
      'team_ids' => teams.pluck(:id)
    }
  end

  def notification_teams!(team_ids)
    ids = Array(team_ids).filter_map { |team_id| Integer(team_id, exception: false) }.uniq
    teams = rule.account.teams.where(id: ids)
    raise ActiveRecord::RecordNotFound, 'Notification team was not found' unless teams.count == ids.length

    teams
  end

  def notification_content(content, teams)
    mentions = teams.map { |team| "(mention://team/#{team.id}/#{team.name})" }
    [content.to_s.strip, *mentions].join("\n")
  end

  def create_opportunity_node(node, results)
    unless card.conversation
      results << { 'node_id' => node.fetch('id'), 'status' => 'skipped', 'reason' => 'no_linked_conversation' }
      return [next_node_id(node), nil]
    end

    created_card = create_opportunity_from_conversation(node)
    results << {
      'node_id' => node.fetch('id'),
      'status' => 'succeeded',
      'created_card_id' => created_card.id
    }
    [next_node_id(node), nil]
  end

  def create_opportunity_from_conversation(node)
    data = node.fetch('data', {}).deep_stringify_keys
    stage = rule.kanban_board.kanban_stages.active.find(data.fetch('stage_id'))
    KanbanCards::CreateFromConversationService.new(
      account: rule.account,
      user: automation_actor!,
      conversation: card.conversation,
      kanban_board: rule.kanban_board,
      kanban_stage: stage,
      subject: data.fetch('subject')
    ).perform!
  end

  def automation_actor!
    rule.account.administrators.first || raise(ActiveRecord::RecordNotFound, 'Automation account has no administrator')
  end

  def audit_log_node(node, results)
    event = create_audit_log_event(node)
    results << {
      'node_id' => node.fetch('id'),
      'status' => 'succeeded',
      'event_id' => event.id,
      'event_type' => event.event_type
    }
    [next_node_id(node), nil]
  end

  def create_audit_log_event(node)
    card.kanban_card_events.create!(
      account: card.account,
      kanban_board: card.kanban_board,
      event_type: 'automation_logged',
      occurred_at: now,
      change_set: {},
      metadata: audit_log_metadata(node)
    )
  end

  def audit_log_metadata(node)
    {
      'content' => node.dig('data', 'content').to_s.strip,
      'automation_rule_id' => rule.id,
      'automation_execution_id' => execution.id,
      'node_id' => node.fetch('id')
    }
  end

  def webhook_node(node, results)
    result = KanbanAutomations::WebhookDeliveryService.new(
      execution: execution,
      rule: rule,
      card: card,
      node: node
    ).perform!
    results << result.merge('node_id' => node.fetch('id'))
    [next_webhook_node_id(node), nil]
  rescue KanbanAutomations::WebhookDeliveryError
    raise unless node.dig('data', 'failure_mode') == 'route'

    results << { 'node_id' => node.fetch('id'), 'status' => 'failed', 'reason' => 'webhook_delivery_failed' }
    [next_node_id(node, source_handle: 'failed'), nil]
  end

  def next_webhook_node_id(node)
    handle = node.dig('data', 'failure_mode') == 'route' ? 'succeeded' : nil
    next_node_id(node, source_handle: handle)
  end

  def end_node(node, results)
    outcome = node.dig('data', 'outcome').presence || 'completed'
    result = {
      'node_id' => node.fetch('id'),
      'status' => outcome == 'failed' ? 'failed' : 'succeeded',
      'outcome' => outcome
    }

    return [nil, failed(results + [result])] if outcome == 'failed'

    [nil, completed(results + [result])]
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

  def wait_for_random_node(node, results)
    data = node.fetch('data', {})
    minimum = Integer(data.fetch('min_minutes'))
    maximum = Integer(data.fetch('max_minutes'))
    raise ArgumentError, 'Workflow random delay interval is invalid' unless minimum.positive? && maximum >= minimum

    delay_minutes = Kernel.rand(minimum..maximum)
    {
      status: :waiting,
      scheduled_at: now + delay_minutes.minutes,
      workflow_state: { 'next_node_id' => next_node_id(node) },
      action_results: results + [{ 'node_id' => node.fetch('id'), 'status' => 'waiting', 'delay_minutes' => delay_minutes }]
    }
  end

  def next_business_time(data)
    schedule = business_hours_schedule(data)

    8.times do |offset|
      date = schedule[:current_time].to_date + offset.days
      next unless schedule[:weekdays].include?(date.cwday)

      available_at = business_time_for_date(schedule, date, offset)
      return available_at if available_at != :unavailable
    end

    raise ArgumentError, 'Workflow business hours cannot find the next available window'
  end

  def business_hours_schedule(data)
    timezone = Time.find_zone!(data.fetch('timezone'))
    {
      timezone: timezone,
      current_time: now.in_time_zone(timezone),
      weekdays: Array(data.fetch('weekdays')).map(&:to_i),
      start_time: data.fetch('start_time'),
      end_time: data.fetch('end_time')
    }
  end

  def business_time_for_date(schedule, date, offset)
    starts_at = schedule[:timezone].parse("#{date} #{schedule[:start_time]}")
    ends_at = schedule[:timezone].parse("#{date} #{schedule[:end_time]}")
    return nil if offset.zero? && schedule[:current_time] >= starts_at && schedule[:current_time] < ends_at
    return starts_at if offset.positive? || schedule[:current_time] < starts_at

    :unavailable
  end

  def wait_until_field(node, results)
    data = node.fetch('data', {}).deep_stringify_keys
    scheduled_at = date_field_value(data.fetch('field_key'), data['timezone']) + data.fetch('offset_hours').to_f.hours
    if scheduled_at <= now
      results << { 'node_id' => node.fetch('id'), 'status' => 'skipped', 'reason' => 'scheduled_time_in_past' }
      return nil
    end

    {
      status: :waiting,
      scheduled_at: scheduled_at,
      workflow_state: { 'next_node_id' => next_date_wait_node_id(node) },
      action_results: results + [{ 'node_id' => node.fetch('id'), 'status' => 'waiting', 'scheduled_at' => scheduled_at.iso8601 }]
    }
  end

  def date_field_value(field_key, timezone_name = nil)
    value = if field_key == 'system_appointment_starts_at'
              workflow_state.dig('event_data', 'appointment_starts_at')
            elsif field_key.start_with?('system_')
              card.public_send(SYSTEM_DATE_FIELD_METHODS.fetch(field_key))
            else
              card.custom_field_values.to_h[field_key]
            end
    timezone = timezone_name.present? ? ActiveSupport::TimeZone[timezone_name] : Time.zone
    return value.in_time_zone(timezone) if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

    timezone.parse(value.to_s) || raise(ArgumentError, "Workflow date field #{field_key} is blank or invalid")
  end

  def execute_action(node)
    data = node.fetch('data', {}).deep_stringify_keys
    action = {
      'action_name' => workflow_action_name(node, data),
      'action_params' => data.fetch('action_params', {})
    }
    KanbanAutomations::ActionService.new(rule: rule, card: card, actions: [action]).perform!.map do |result|
      result.merge('node_id' => node.fetch('id'))
    end
  end

  def workflow_action_name(node, data)
    return node['type'] if %w[set_field update_contact complete_next_action mark_won mark_lost].include?(node['type'])

    data.fetch('action_name')
  end

  def next_round_robin_option(node)
    options = Array(node.dig('data', 'options'))
    raise ArgumentError, 'Round-robin needs at least two options' if options.length < 2

    rule.with_lock do
      option = options[rule.round_robin_cursor % options.length]
      rule.update!(round_robin_cursor: rule.round_robin_cursor + 1)
      option
    end
  end

  def send_message(node)
    result = KanbanAutomations::WorkflowMessageService.new(
      card: card,
      data: node.fetch('data', {}),
      event_data: workflow_state['event_data'],
      now: now
    ).perform!
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
    conditions = condition_entries(data)
    return false if conditions.blank?

    matcher = KanbanAutomations::ConditionsMatcher.new(rule: rule, card: card)
    conditions.drop(1).reduce(matcher.matches_field_condition?(conditions.first)) do |matches, condition|
      condition_matches = matcher.matches_field_condition?(condition)
      condition_join_operator(condition, data) == 'or' ? matches || condition_matches : matches && condition_matches
    end
  end

  def condition_join_operator(condition, data)
    condition['join_operator'].presence || (data['match_mode'] == 'any' ? 'or' : 'and')
  end

  def condition_entries(data)
    entries = Array(data['conditions']).filter_map(&:presence)
    return entries if entries.present?

    [data.slice('field_key', 'operator', 'value')]
  end

  def completed(results)
    { status: :succeeded, scheduled_at: nil, workflow_state: {}, action_results: results }
  end

  def failed(results)
    { status: :failed, scheduled_at: nil, workflow_state: {}, action_results: results }
  end

  def stamp_outcome(outcome, results_count)
    action_results = outcome.fetch(:action_results, [])
    stamp_results(action_results, results_count)
    preserve_event_data_while_waiting(outcome)
    outcome
  end

  def preserve_event_data_while_waiting(outcome)
    return unless outcome[:status] == :waiting && workflow_state['event_data'].present?

    outcome[:workflow_state] = outcome.fetch(:workflow_state, {}).merge('event_data' => workflow_state['event_data'])
  end

  def stamp_results(results, start_index)
    results.drop(start_index).each do |result|
      result['executed_at'] ||= now.iso8601
    end
  end
end
# rubocop:enable Metrics/ClassLength
