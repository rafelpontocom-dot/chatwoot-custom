class RaevoAi::HandoffContext
  class UnauthorizedConversation < StandardError; end
  class IneligibleInbox < StandardError; end
  class InvalidHandoffConfiguration < StandardError; end

  def initialize(integration:, conversation:)
    @integration = integration
    @conversation = conversation
  end

  def payload
    validate_conversation!

    configuration = handoff_configuration
    validate_inbox!(configuration[:allowed_inbox_ids])
    validate_destination!(configuration)

    {
      'clinic_id' => @integration.clinic_id,
      'account_id' => @integration.account_id,
      'conversation_id' => @conversation.display_id,
      'contact_id' => @conversation.contact_id,
      'handoff_team_id' => configuration[:team_id],
      'handoff_assignee_id' => configuration[:assignee_id],
      'handoff_labels' => configuration[:labels]
    }
  end

  private

  def validate_conversation!
    return if @conversation.account_id == @integration.account_id

    raise UnauthorizedConversation, 'conversation does not belong to the integration account'
  end

  def handoff_configuration
    handoff = @integration.settings.fetch('handoff', {})
    team_id = positive_integer(handoff['team_id'])
    assignee_id = positive_integer(handoff['assignee_id'])
    allowed_inbox_ids = Array(handoff['allowed_inbox_ids']).filter_map { |id| positive_integer(id) }.uniq
    labels = Array(handoff['labels']).filter_map { |label| label.to_s.strip.presence }.uniq

    raise InvalidHandoffConfiguration, 'handoff requires exactly one destination: team_id or assignee_id' unless [team_id, assignee_id].compact.one?

    raise InvalidHandoffConfiguration, 'handoff requires allowed_inbox_ids and labels' if allowed_inbox_ids.empty? || labels.empty?

    { team_id: team_id, assignee_id: assignee_id, allowed_inbox_ids: allowed_inbox_ids, labels: labels }
  end

  def validate_inbox!(allowed_inbox_ids)
    return if allowed_inbox_ids.include?(@conversation.inbox_id)

    raise IneligibleInbox, 'conversation inbox is not enabled for Raevo handoff'
  end

  def validate_destination!(configuration)
    validate_team!(configuration[:team_id]) if configuration[:team_id].present?
    validate_assignee!(configuration[:assignee_id]) if configuration[:assignee_id].present?
  end

  def validate_team!(team_id)
    return if Team.exists?(id: team_id, account_id: @integration.account_id)

    raise InvalidHandoffConfiguration, 'handoff team must belong to the integration account'
  end

  def validate_assignee!(assignee_id)
    return if @integration.account.users.exists?(id: assignee_id)

    raise InvalidHandoffConfiguration, 'handoff assignee must belong to the integration account'
  end

  def positive_integer(value)
    integer = Integer(value)
    integer.positive? ? integer : nil
  rescue ArgumentError, TypeError
    nil
  end
end
