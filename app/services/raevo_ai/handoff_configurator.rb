class RaevoAi::HandoffConfigurator
  class InvalidConfiguration < StandardError; end

  def initialize(integration:)
    @integration = integration
  end

  def configure!(team_id:, assignee_id:, allowed_inbox_ids:, labels:)
    team = positive_integer(team_id)
    assignee = positive_integer(assignee_id)
    raise InvalidConfiguration, 'handoff requires exactly one destination' unless [team, assignee].compact.one?

    validate_team!(team) if team
    validate_assignee!(assignee) if assignee
    inbox_ids = normalized_inbox_ids(allowed_inbox_ids)
    handoff_labels = normalized_labels(labels)
    raise InvalidConfiguration, 'handoff requires inboxes and labels' if inbox_ids.empty? || handoff_labels.empty?

    configuration = {
      'team_id' => team,
      'assignee_id' => assignee,
      'allowed_inbox_ids' => inbox_ids,
      'labels' => handoff_labels
    }
    settings = @integration.settings.deep_dup
    settings['handoff'] = configuration
    @integration.update!(settings: settings)
    configuration
  end

  private

  def validate_team!(team_id)
    return if @integration.account.teams.exists?(id: team_id)

    raise InvalidConfiguration, 'handoff team must belong to the integration account'
  end

  def validate_assignee!(assignee_id)
    return if @integration.account.users.exists?(id: assignee_id)

    raise InvalidConfiguration, 'handoff assignee must belong to the integration account'
  end

  def normalized_inbox_ids(values)
    submitted = Array(values).compact_blank
    ids = submitted.map { |value| Integer(value.to_s, 10) }.select(&:positive?).uniq
    return ids if ids.length == submitted.length && @integration.account.inboxes.where(id: ids).count == ids.length

    raise InvalidConfiguration, 'handoff inboxes must belong to the integration account'
  rescue ArgumentError, TypeError
    raise InvalidConfiguration, 'handoff inboxes must belong to the integration account'
  end

  def normalized_labels(values)
    Array(values).flat_map { |value| value.to_s.split(',') }.filter_map { |value| value.strip.presence }.uniq
  end

  def positive_integer(value)
    integer = Integer(value.to_s, 10)
    integer.positive? ? integer : nil
  rescue ArgumentError, TypeError
    nil
  end
end
