# rubocop:disable Metrics/ClassLength -- Node validations are intentionally centralized with the board reference checks.
class KanbanAutomations::FlowDefinitionValidator
  DATE_FIELD_TYPES = %w[date datetime].freeze
  END_OUTCOMES = %w[completed handed_off stopped failed].freeze
  ROUND_ROBIN_AVAILABILITY_POLICIES = %w[any online_only online_or_busy].freeze
  CONTACT_BOOLEAN_ATTRIBUTE_KEYS = %w[
    marketing_messages_opt_in
    birthday_messages_opt_in
    appointment_reminders_opt_in
  ].freeze
  CONTACT_DATE_ATTRIBUTE_KEYS = %w[date_of_birth].freeze
  ACTION_REFERENCE_VALIDATORS = {
    'move_stage' => :validate_action_stage,
    'assign_owner' => :validate_action_owner,
    'assign_round_robin' => :validate_action_round_robin,
    'set_field' => :validate_action_field,
    'increment_field' => :validate_action_field,
    'clear_field' => :validate_action_field,
    'enroll_cadence' => :validate_action_cadence,
    'add_label' => :validate_action_label,
    'remove_label' => :validate_action_label,
    'add_note' => :validate_action_note,
    'update_contact' => :validate_action_contact,
    'complete_next_action' => :validate_action_next_action,
    'mark_lost' => :validate_action_lost_reason
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
      validate_random_delay_node(node, data)
      validate_wait_until_field_node(node, data)
      validate_wait_for_response_node(node, data)
      validate_wait_for_inactivity_node(node, data)
      validate_wait_for_business_hours_node(node, data)
      validate_stage_guard_node(node)
      validate_action_node(node, data)
      validate_decision_nodes(node, data)
      validate_operation_nodes(node, data)
      validate_webhook_node(node, data)
      validate_end_node(node, data)
      validate_node_paths(node, data)
    end
  end

  def validate_end_node(node, data)
    return unless node[:type].to_s == 'end'

    outcome = data[:outcome].presence || 'completed'
    return if END_OUTCOMES.include?(outcome)

    add_error("End node #{node[:id]} has an unsupported outcome")
  end

  def validate_decision_nodes(node, data)
    validate_condition_node(node, data)
    validate_filter_node(node, data)
    validate_message_eligibility_node(node, data)
    validate_round_robin_node(node, data)
  end

  def validate_operation_nodes(node, data)
    validate_human_handoff_node(node, data)
    validate_audit_log_node(node, data)
  end

  def validate_node_paths(node, data)
    validate_condition_paths(node)
    validate_message_eligibility_paths(node)
    validate_message_paths(node, data)
    validate_date_wait_paths(node, data)
    validate_response_wait_paths(node, data)
    validate_inactivity_wait_paths(node, data)
    validate_business_hours_paths(node, data)
    validate_webhook_paths(node, data)
    validate_round_robin_paths(node, data)
  end

  def validate_date_wait_paths(node, data)
    return unless node[:type] == 'wait_until_field'

    unless date_wait_failure_mode_valid?(data)
      add_error("Date wait node #{node[:id]} has an unsupported failure policy")
      return
    end
    return unless date_wait_failure_mode(data) == 'route'

    handles = edges.filter_map { |edge| edge[:sourceHandle].to_s if edge[:source].to_s == node[:id].to_s }
    return if handles.tally.slice('succeeded', 'failed') == { 'succeeded' => 1, 'failed' => 1 }

    add_error("Date wait node #{node[:id]} needs available and unavailable paths")
  end

  def date_wait_failure_mode(data)
    data[:failure_mode].presence || 'stop'
  end

  def date_wait_failure_mode_valid?(data)
    %w[stop route].include?(date_wait_failure_mode(data))
  end

  def validate_response_wait_paths(node, data)
    return unless node[:type] == 'wait_for_response'
    return if response_wait_timeout_mode(data) == 'continue'

    unless %w[continue route].include?(response_wait_timeout_mode(data))
      add_error("Response wait node #{node[:id]} has an unsupported timeout policy")
      return
    end
    return if response_wait_paths_valid?(node)

    add_error("Response wait node #{node[:id]} needs received and timeout paths")
  end

  def response_wait_timeout_mode(data)
    data[:timeout_mode].presence || 'continue'
  end

  def response_wait_paths_valid?(node)
    handles = edges.filter_map { |edge| edge[:sourceHandle].to_s if edge[:source].to_s == node[:id].to_s }
    handles.tally.slice('received', 'timeout') == { 'received' => 1, 'timeout' => 1 }
  end

  def validate_inactivity_wait_paths(node, data)
    return unless node[:type] == 'wait_for_inactivity'
    return if inactivity_wait_interruption_mode(data) == 'stop'

    unless %w[stop route].include?(inactivity_wait_interruption_mode(data))
      add_error("Inactivity wait node #{node[:id]} has an unsupported interruption policy")
      return
    end
    return if inactivity_wait_paths_valid?(node)

    add_error("Inactivity wait node #{node[:id]} needs inactivity and response paths")
  end

  def inactivity_wait_interruption_mode(data)
    data[:interruption_mode].presence || 'stop'
  end

  def inactivity_wait_paths_valid?(node)
    handles = edges.filter_map { |edge| edge[:sourceHandle].to_s if edge[:source].to_s == node[:id].to_s }
    handles.tally.slice('inactive', 'responded') == { 'inactive' => 1, 'responded' => 1 }
  end

  def validate_business_hours_paths(node, data)
    return unless node[:type] == 'wait_for_business_hours'
    return if business_hours_failure_mode(data) == 'stop'

    unless %w[stop route].include?(business_hours_failure_mode(data))
      add_error("Business-hours node #{node[:id]} has an unsupported failure policy")
      return
    end
    return if business_hours_paths_valid?(node)

    add_error("Business-hours node #{node[:id]} needs available and unavailable paths")
  end

  def business_hours_failure_mode(data)
    data[:failure_mode].presence || 'stop'
  end

  def business_hours_paths_valid?(node)
    handles = edges.filter_map { |edge| edge[:sourceHandle].to_s if edge[:source].to_s == node[:id].to_s }
    handles.tally.slice('succeeded', 'failed') == { 'succeeded' => 1, 'failed' => 1 }
  end

  def validate_message_node(node, data)
    return unless node[:type] == 'send_message'

    valid_channel = KanbanAppointmentReminderRule::CHANNELS.include?(data[:channel].to_s)
    valid_message = data[:content].present? && data[:opt_in_attribute_key].present?
    valid_policy = message_policy_valid?(data)
    valid_attachment = KanbanAutomations::MessageAttachmentService.new(data: data).valid?
    add_error("Message node #{node[:id]} is incomplete") unless valid_channel && valid_message && valid_policy && valid_attachment
  end

  def validate_message_paths(node, data)
    return unless node[:type] == 'send_message'

    mode = message_failure_mode(data)
    unless %w[stop route].include?(mode)
      add_error("Message node #{node[:id]} has an unsupported failure policy")
      return
    end
    return unless mode == 'route'
    return if message_failure_paths_valid?(node)

    add_error("Message node #{node[:id]} needs sent and not-sent paths")
  end

  def message_failure_mode(data)
    data[:failure_mode].presence || 'stop'
  end

  def message_failure_paths_valid?(node)
    handles = edges.filter_map do |edge|
      edge[:sourceHandle].to_s if edge[:source].to_s == node[:id].to_s
    end
    handles.tally.slice('succeeded', 'failed') == { 'succeeded' => 1, 'failed' => 1 }
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

  def validate_random_delay_node(node, data)
    return unless node[:type] == 'random_delay'

    minimum = Integer(data[:min_minutes], exception: false)
    maximum = Integer(data[:max_minutes], exception: false)
    return if minimum&.positive? && maximum && maximum >= minimum

    add_error("Random delay node #{node[:id]} needs a valid minute interval")
  end

  def validate_stage_guard_node(node)
    return unless node[:type] == 'stage_guard'
    return if Array(rule.trigger_conditions[:stage_ids]).present?

    add_error("Stage guard node #{node[:id]} needs a stage selected in the trigger")
  end

  def validate_wait_until_field_node(node, data)
    return unless node[:type] == 'wait_until_field'

    valid_field = datetime_field?(data[:field_key])
    valid_offset = Float(data[:offset_hours])
    valid_timezone = data[:timezone].blank? || ActiveSupport::TimeZone[data[:timezone]].present?
    return if valid_field && valid_offset.finite? && valid_timezone

    add_error("Date wait node #{node[:id]} is incomplete")
  rescue ArgumentError, TypeError
    add_error("Date wait node #{node[:id]} is incomplete")
  end

  def validate_wait_for_response_node(node, data)
    return unless node[:type] == 'wait_for_response'

    add_error("Response wait node #{node[:id]} needs positive timeout hours") unless data[:timeout_hours].to_f.positive?
  end

  def validate_wait_for_inactivity_node(node, data)
    return unless node[:type] == 'wait_for_inactivity'

    add_error("Inactivity wait node #{node[:id]} needs positive timeout hours") unless data[:timeout_hours].to_f.positive?
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
    return unless %w[action set_field update_contact complete_next_action mark_won mark_lost].include?(node[:type])

    action_name = workflow_action_name(node, data)
    add_error("Action node #{node[:id]} has an unsupported action") unless KanbanAutomationRule::ACTION_NAMES.include?(action_name)
    validate_action_references(node, action_name, data[:action_params].to_h.with_indifferent_access)
  end

  def validate_condition_node(node, data)
    return unless node[:type] == 'condition'

    return if condition_branches_valid?(data) || (valid_condition_match_mode?(data) && condition_entries_valid?(data))

    add_error("Condition node #{node[:id]} is incomplete")
  end

  def validate_filter_node(node, data)
    return unless node[:type] == 'filter'
    return if valid_condition_match_mode?(data) && condition_entries_valid?(data)

    add_error("Filter node #{node[:id]} is incomplete")
  end

  def validate_message_eligibility_node(node, data)
    return unless node[:type] == 'message_eligibility'

    valid_channel = KanbanAppointmentReminderRule::CHANNELS.include?(data[:channel].to_s)
    add_error("Message eligibility node #{node[:id]} is incomplete") unless valid_channel && data[:opt_in_attribute_key].present?
  end

  def validate_human_handoff_node(node, data)
    return unless node[:type] == 'human_handoff'

    references = human_handoff_references(data)
    validate_human_handoff_destinations(node, data, references)
    add_error("Human handoff node #{node[:id]} cannot have an outgoing path") if outgoing_node_ids(node[:id].to_s).present?
  end

  def human_handoff_references(data)
    {
      owner: rule.account.users.find_by(id: data[:owner_id]),
      team: rule.account.teams.find_by(id: data[:team_id])
    }
  end

  def validate_human_handoff_destinations(node, data, references)
    owner = references[:owner]
    team = references[:team]
    add_error("Human handoff node #{node[:id]} needs an agent or team from this account") if owner.blank? && team.blank?
    add_error("Human handoff node #{node[:id]} references a team outside this account") if data[:team_id].present? && team.blank?
    add_error("Human handoff node #{node[:id]} references an agent outside this account") if data[:owner_id].present? && owner.blank?
  end

  def validate_audit_log_node(node, data)
    return unless node[:type] == 'audit_log'

    add_error("Audit log node #{node[:id]} needs a note") if data[:content].to_s.strip.blank?
  end

  def condition_branches_valid?(data)
    branches = condition_branches(data)
    return false if branches.blank? || data[:fallback_id].blank?

    condition_branch_ids_valid?(branches, data[:fallback_id]) && branches.all? { |branch| condition_branch_valid?(branch) }
  end

  def condition_branch_ids_valid?(branches, fallback_id)
    branch_ids = branches.pluck(:id).map(&:to_s)
    branch_ids.all?(&:present?) && branch_ids.uniq.length == branch_ids.length && branch_ids.exclude?(fallback_id.to_s)
  end

  def condition_branch_valid?(branch)
    valid_condition_match_mode?(branch) && condition_entries_valid?(branch)
  end

  def valid_condition_match_mode?(data)
    %w[all any].include?(data[:match_mode].presence || 'all')
  end

  def condition_entries_valid?(data)
    entries = condition_entries(data)
    entries.present? && entries.each_with_index.all? do |condition, index|
      valid_condition_entry?(condition) && (index.zero? || valid_condition_join_operator?(condition, data))
    end
  end

  def valid_condition_join_operator?(condition, data)
    join_operator = condition[:join_operator].presence || (data[:match_mode] == 'any' ? 'or' : 'and')
    %w[and or].include?(join_operator)
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

  def condition_branches(data)
    Array(data[:branches]).map { |branch| branch.to_h.with_indifferent_access }
  end

  def validate_webhook_node(node, data)
    return unless node[:type] == 'webhook'

    connection = rule.kanban_board.kanban_automation_connections.active.find_by(id: data[:connection_id])
    add_error("Webhook node #{node[:id]} references an active connection on this board") if connection.blank?
    return if data[:failure_mode].blank? || %w[stop route].include?(data[:failure_mode])

    add_error("Webhook node #{node[:id]} has an unsupported failure policy")
  end

  def validate_webhook_paths(node, data)
    return unless node[:type] == 'webhook' && data[:failure_mode] == 'route'

    handles = edges.filter_map do |edge|
      edge[:sourceHandle].to_s if edge[:source].to_s == node[:id].to_s
    end
    return if handles.tally.slice('succeeded', 'failed') == { 'succeeded' => 1, 'failed' => 1 }

    add_error("Webhook node #{node[:id]} needs succeeded and failed paths")
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
    branches = condition_branches(node[:data].to_h.with_indifferent_access)
    return validate_condition_branch_paths(node, handles, branches) if branches.present?

    return if handles.tally.slice('yes', 'no') == { 'yes' => 1, 'no' => 1 }

    add_error("Condition node #{node[:id]} needs yes and no paths")
  end

  def validate_message_eligibility_paths(node)
    return unless node[:type] == 'message_eligibility'

    handles = edges.filter_map do |edge|
      edge[:sourceHandle].to_s if edge[:source].to_s == node[:id].to_s
    end
    return if handles.tally.slice('eligible', 'otherwise') == { 'eligible' => 1, 'otherwise' => 1 }

    add_error("Message eligibility node #{node[:id]} needs eligible and otherwise paths")
  end

  def validate_condition_branch_paths(node, handles, branches)
    expected = branches.pluck(:id).map(&:to_s) + [node[:data].to_h.with_indifferent_access[:fallback_id].to_s]
    return if handles.sort == expected.sort

    add_error("Condition node #{node[:id]} needs one path for every output")
  end

  def condition_field_exists?(field_key)
    return true if KanbanCard::SYSTEM_CONDITION_VALUE_METHODS.key?(field_key.to_s)

    rule.kanban_board.configured_custom_field_definitions.any? { |field| field['key'] == field_key.to_s }
  end

  def datetime_field?(field_key)
    if field_key.to_s.start_with?('system_')
      return %w[system_starts_at system_due_at system_next_action_at system_appointment_starts_at].include?(field_key.to_s)
    end

    rule.kanban_board.configured_custom_field_definitions.any? do |field|
      field['key'] == field_key.to_s && DATE_FIELD_TYPES.include?(field['field_type'])
    end
  end

  def validate_action_references(node, action_name, params)
    validator = ACTION_REFERENCE_VALIDATORS[action_name]
    send(validator, node, params) if validator
  end

  def workflow_action_name(node, data)
    return node[:type].to_s if %w[set_field update_contact complete_next_action mark_won mark_lost].include?(node[:type].to_s)

    data[:action_name].to_s
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
    return if ROUND_ROBIN_AVAILABILITY_POLICIES.include?(params[:availability_policy].presence || 'any')

    add_error("Action node #{node[:id]} has an unsupported availability policy")
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

  def validate_action_lost_reason(node, params)
    reason = params[:lost_reason].to_s
    return if rule.kanban_board.configured_lost_reason_options.include?(reason)

    add_error("Action node #{node[:id]} needs a configured lost reason")
  end

  def validate_action_contact(node, params)
    attribute_key = params[:attribute_key].to_s
    unless safe_contact_attribute_key?(attribute_key)
      add_error("Contact update node #{node[:id]} needs a safe custom attribute key")
      return
    end

    validate_contact_attribute_value(node, attribute_key, params[:value])
  end

  def validate_action_next_action(node, params)
    return if params[:schedule_next_action] == false

    has_type = params[:next_action_type].present?
    has_date = params[:next_action_at].present?
    unless has_type == has_date
      add_error("Completion node #{node[:id]} needs a next action type and date together")
      return
    end

    return unless has_date && Time.zone.parse(params[:next_action_at].to_s).blank?

    add_error("Completion node #{node[:id]} needs a valid next action date")
  end

  def safe_contact_attribute_key?(attribute_key)
    attribute_key.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/) && Contact.column_names.exclude?(attribute_key)
  end

  def validate_contact_attribute_value(node, attribute_key, value)
    if CONTACT_BOOLEAN_ATTRIBUTE_KEYS.include?(attribute_key)
      return if [true, false].include?(value) || %w[true false 1 0].include?(value.to_s)

      add_error("Contact update node #{node[:id]} needs a true or false consent value")
      return
    end

    return unless CONTACT_DATE_ATTRIBUTE_KEYS.include?(attribute_key)

    Date.iso8601(value.to_s)
  rescue Date::Error
    add_error("Contact update node #{node[:id]} needs a valid ISO date")
  end

  def add_error(message)
    rule.errors.add(:flow_definition, message)
  end
end
# rubocop:enable Metrics/ClassLength
