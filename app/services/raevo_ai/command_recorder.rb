class RaevoAi::CommandRecorder
  Claim = Data.define(:command, :created)

  class Conflict < StandardError; end

  def initialize(integration:, action_id:, command_type:, payload:)
    @integration = integration
    @action_id = action_id
    @command_type = command_type
    @payload = payload
  end

  def claim
    existing_command = @integration.raevo_ai_commands.find_by(action_id: @action_id)
    return existing_claim(existing_command) if existing_command

    Claim.new(
      command: @integration.raevo_ai_commands.create!(
        action_id: @action_id,
        command_type: @command_type,
        payload_digest: payload_digest,
        state: 'claimed'
      ),
      created: true
    )
  rescue ActiveRecord::RecordNotUnique
    existing_claim(@integration.raevo_ai_commands.find_by!(action_id: @action_id))
  end

  private

  def existing_claim(command)
    unless command.command_type == @command_type && ActiveSupport::SecurityUtils.secure_compare(command.payload_digest, payload_digest)
      raise Conflict, 'action_id was already claimed with a different command'
    end

    Claim.new(command: command, created: false)
  end

  def payload_digest
    @payload_digest ||= Digest::SHA256.hexdigest(JSON.generate(canonicalize(@payload)))
  end

  def canonicalize(value)
    case value
    when Hash
      value.each_with_object({}) do |(key, nested_value), result|
        result[key.to_s] = canonicalize(nested_value)
      end.sort.to_h
    when Array
      value.map { |item| canonicalize(item) }
    else
      value
    end
  end
end
