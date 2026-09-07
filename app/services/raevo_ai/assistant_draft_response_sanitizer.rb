class RaevoAi::AssistantDraftResponseSanitizer
  DRAFT_FIELDS = %w[id version_number revision state editable_clusters].freeze
  ACTIVE_VERSION_FIELDS = %w[id version_number].freeze
  SIMULATION_FIELDS = %w[draft_id comparison response_bubbles intent simulated_actions blocked_actions execution].freeze
  SIMULATION_COMPARISON_FIELDS = %w[active_version_number draft_version_number].freeze
  SIMULATION_EXECUTION_FIELDS = %w[delivery_disposition mutable_tools persistence].freeze
  SIMULATION_ACTION_FIELDS = %w[type disposition].freeze
  BLOCKED_ACTION_FIELDS = %w[type reason].freeze
  EVALUATION_FIELDS = %w[verdict criteria].freeze
  EVALUATION_CRITERION_FIELDS = %w[id status reason].freeze
  REVIEW_FIELDS = %w[id draft_id draft_revision decision created_at].freeze
  PUBLICATION_FIELDS = %w[id version_number previous_active_version_id state published_at].freeze

  def draft(payload)
    record = payload['draft']
    return nil if record.nil?
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable' unless record.is_a?(Hash)

    record.slice(*DRAFT_FIELDS)
  end

  def read(payload)
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable' unless payload.is_a?(Hash)

    active_version = payload['active_version']
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable' unless active_version.nil? || active_version.is_a?(Hash)

    { 'draft' => draft(payload), 'active_version' => active_version&.slice(*ACTIVE_VERSION_FIELDS) }
  end

  def simulation(payload)
    return nil unless payload.is_a?(Hash)

    simulated = payload['simulation']
    evaluation = payload['evaluation']
    return nil unless simulated.is_a?(Hash) && evaluation.is_a?(Hash)
    return nil unless valid_simulation?(simulated, evaluation)

    sanitized_simulation = simulated.slice(*SIMULATION_FIELDS).merge(
      'comparison' => simulated['comparison'].slice(*SIMULATION_COMPARISON_FIELDS),
      'execution' => simulated['execution'].slice(*SIMULATION_EXECUTION_FIELDS),
      'simulated_actions' => array_of_hashes(simulated['simulated_actions'], SIMULATION_ACTION_FIELDS),
      'blocked_actions' => array_of_hashes(simulated['blocked_actions'], BLOCKED_ACTION_FIELDS)
    )
    return nil unless sanitized_simulation['simulated_actions'] && sanitized_simulation['blocked_actions']

    {
      'simulation' => sanitized_simulation,
      'evaluation' => evaluation.slice(*EVALUATION_FIELDS).merge(
        'criteria' => array_of_hashes(evaluation['criteria'], EVALUATION_CRITERION_FIELDS)
      )
    }
  end

  def review(payload)
    item(payload, 'review', REVIEW_FIELDS)
  end

  def publication(payload, key)
    item(payload, key, PUBLICATION_FIELDS)
  end

  private

  def valid_simulation?(simulation, evaluation)
    simulation['comparison'].is_a?(Hash) && simulation['execution'].is_a?(Hash) &&
      evaluation['criteria'].is_a?(Array) && %w[ready_for_human_review blocked].include?(evaluation['verdict'])
  end

  def item(payload, key, fields)
    return nil unless payload.is_a?(Hash) && payload[key].is_a?(Hash)

    payload[key].slice(*fields)
  end

  def array_of_hashes(value, fields)
    return nil unless value.is_a?(Array) && value.all?(Hash)

    value.map { |item| item.slice(*fields) }
  end
end
