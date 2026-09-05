class RaevoAi::CrmFieldExecutor
  class LockConflict < StandardError; end
  class InvalidCard < StandardError; end
  class InvalidValue < StandardError; end

  def initialize(integration:, card:, command:)
    @integration = integration
    @card = card
    @action_id = command.fetch(:action_id)
    @board_key = command.fetch(:board_key)
    @expected_lock_version = command.fetch(:expected_lock_version)
    @fields = command.fetch(:fields)
  end

  def perform
    catalog = RaevoAi::CrmCatalog.new(integration: @integration)
    board = catalog.resolve_board!(@board_key)
    validate_card!(board)
    resolved_fields = resolve_fields(catalog)
    claim = RaevoAi::CommandRecorder.new(
      integration: @integration,
      action_id: @action_id,
      command_type: 'crm.update_fields',
      payload: command_payload
    ).claim

    return claim.command.result if claim.command.state == 'applied'

    apply_claim!(claim.command, resolved_fields)
  end

  private

  def validate_card!(board)
    return if @card.account_id == @integration.account_id && @card.kanban_board_id == board.id

    raise InvalidCard, 'card does not belong to the configured board in the integration account'
  end

  def apply_claim!(claimed_command, resolved_fields)
    RaevoAiCommand.transaction do
      command = claimed_command.lock!
      command.state == 'applied' ? command.result : apply_pending_command!(command, resolved_fields)
    end
  end

  def apply_pending_command!(command, resolved_fields)
    @card.reload
    raise LockConflict, 'card lock_version does not match the expected version' unless @card.lock_version == @expected_lock_version

    apply_fields!(resolved_fields)
    result = receipt(resolved_fields)
    command.update!(state: 'applied', result: result)
    result
  end

  def resolve_fields(catalog)
    Array(@fields).map do |field|
      key = field.fetch('key').to_s
      value = field.fetch('value')
      configuration = catalog.resolve_field!(@board_key, key)
      validate_value!(configuration, value)
      configuration.merge(value: value)
    end
  end

  def validate_value!(configuration, value)
    validate_value_type!(configuration[:type], value)
    values = configuration[:values]
    return if values.empty? || values.include?(value.to_s)

    raise InvalidValue, 'field value is not allowed by the tenant catalog'
  end

  def validate_value_type!(field_type, value)
    case field_type
    when 'text', 'textarea', 'url'
      raise InvalidValue, 'field value must be a string' unless value.is_a?(String)
    when 'datetime'
      raise InvalidValue, 'datetime field value must be ISO 8601' unless value.is_a?(String)

      Time.iso8601(value)
    end
  rescue ArgumentError
    raise InvalidValue, 'datetime field value must be ISO 8601'
  end

  def apply_fields!(fields)
    values = @card.custom_field_values.to_h.deep_dup
    fields.each do |field|
      next if field[:overwrite] == 'if_empty' && populated?(values[field[:key]])

      values[field[:key]] = field[:value]
    end
    @card.update!(custom_field_values: values)
  end

  def populated?(value)
    value == false || value.present?
  end

  def command_payload
    {
      'card_id' => @card.id,
      'board_key' => @board_key,
      'expected_lock_version' => @expected_lock_version,
      'fields' => @fields
    }
  end

  def receipt(fields)
    {
      'action_id' => @action_id,
      'status' => 'applied',
      'receipts' => {
        'fields' => fields.map do |field|
          {
            'key' => field[:key],
            'status' => populated?(@card.custom_field_values[field[:key]]) ? 'applied' : 'skipped',
            'value' => @card.custom_field_values[field[:key]]
          }
        end
      }
    }
  end
end
