class RaevoAi::IntegrationProvisioner
  class InvalidProvisioning < StandardError; end

  def initialize(integration:, command_token: nil)
    @integration = integration
    @command_token = command_token.to_s
  end

  def provision!(board_key:, board_id:, initial_stage_id:, stages:, ai_tab_board_ids:)
    ensure_inactive!
    ensure_command_token!

    ActiveRecord::Base.transaction do
      publish_catalog!(board_key: board_key, board_id: board_id, initial_stage_id: initial_stage_id, stages: stages)
      tab = configure_tab!(ai_tab_board_ids)
      persist_command_token!

      {
        'enabled' => false,
        'board_key' => board_key.to_s,
        'board_ids' => tab.fetch('board_ids')
      }
    end
  end

  def activate!(actor_ref:)
    ensure_inactive!
    ensure_provisioned!

    @integration.update!(
      enabled: true,
      settings: @integration.settings.merge(
        'activation' => { 'actor_ref' => actor_ref.to_s, 'activated_at' => Time.current.iso8601 }
      )
    )

    { 'enabled' => true, 'clinic_id' => @integration.clinic_id }
  end

  def reconfigure!(board_key:, board_id:, initial_stage_id:, stages:, ai_tab_board_ids:)
    ensure_inactive!
    ensure_provisioned!

    ActiveRecord::Base.transaction do
      publish_catalog!(board_key: board_key, board_id: board_id, initial_stage_id: initial_stage_id, stages: stages)
      tab = configure_tab!(ai_tab_board_ids)

      {
        'enabled' => false,
        'board_key' => board_key.to_s,
        'board_ids' => tab.fetch('board_ids')
      }
    end
  end

  private

  def ensure_inactive!
    raise InvalidProvisioning, 'integration is already enabled' if @integration.enabled?
  end

  def ensure_command_token!
    raise InvalidProvisioning, 'command token must contain at least 32 characters' if @command_token.length < 32
  end

  def publish_catalog!(board_key:, board_id:, initial_stage_id:, stages:)
    RaevoAi::CrmCatalogPublisher.new(integration: @integration).publish!(
      board_key: board_key,
      board_id: board_id,
      initial_stage_id: initial_stage_id,
      stages: stages
    )
  end

  def configure_tab!(board_ids)
    RaevoAi::OpportunityAiTabProvisioner.new(integration: @integration).configure!(board_ids: board_ids, enabled: true)
  end

  def persist_command_token!
    @integration.update!(
      settings: @integration.settings.merge('command_token_digest' => Digest::SHA256.hexdigest(@command_token))
    )
  end

  def ensure_provisioned!
    settings = @integration.settings
    provisioned = settings['command_token_digest'].present? &&
                  settings.dig('crm', 'boards').present? &&
                  settings.dig('opportunity_ai_tab', 'enabled') == true &&
                  settings.dig('opportunity_ai_tab', 'board_ids').present?
    raise InvalidProvisioning, 'integration is not provisioned' unless provisioned
  end
end
