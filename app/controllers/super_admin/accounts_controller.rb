class SuperAdmin::AccountsController < SuperAdmin::ApplicationController
  SEMANTIC_STAGE_EVENTS = {
    'new_lead' => [],
    'qualified' => %w[new_lead qualified],
    'no_response' => %w[new_lead qualified price_informed future_follow_up scheduling_requested],
    'price_informed' => %w[new_lead qualified no_response future_follow_up],
    'future_follow_up' => %w[new_lead qualified no_response price_informed scheduling_requested],
    'scheduling_requested' => %w[new_lead qualified no_response price_informed future_follow_up],
    'scheduled' => ['scheduling_requested'],
    'won' => ['scheduled'],
    'lost' => %w[new_lead qualified no_response price_informed future_follow_up scheduling_requested]
  }.freeze

  # Overwrite any of the RESTful controller actions to implement custom behavior
  # For example, you may want to send an email after a foo is updated.
  #
  # def update
  #   super
  #   send_foo_updated_email(requested_resource)
  # end

  # Override this method to specify custom lookup behavior.
  # This will be used to set the resource for the `show`, `edit`, and `update`
  # actions.
  #
  # def find_resource(param)
  #   Foo.find_by!(slug: param)
  # end

  # The result of this lookup will be available as `requested_resource`

  # Override this if you have certain roles that require a subset
  # this will be used to set the records shown on the `index` action.
  #
  # def scoped_resource
  #   if current_user.super_admin?
  #     resource_class
  #   else
  #     resource_class.with_less_stuff
  #   end
  # end

  # Override `resource_params` if you want to transform the submitted
  # data before it's persisted. For example, the following would turn all
  # empty values into nil values. It uses other APIs such as `resource_class`
  # and `dashboard`:
  #
  def resource_params
    permitted_params = super
    permitted_params[:limits] = permitted_params[:limits].to_h.compact if permitted_params.key?(:limits)
    permitted_params[:captain_models] = permitted_params[:captain_models].to_h.compact_blank.presence if permitted_params.key?(:captain_models)
    permitted_params[:selected_feature_flags] = params[:enabled_features].keys.map(&:to_sym) if params[:enabled_features].present?
    permitted_params
  end

  # See https://administrate-prototype.herokuapp.com/customizing_controller_actions
  # for more information

  def seed
    Internal::SeedAccountJob.perform_later(requested_resource)
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Account seeding triggered')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  def reset_cache
    requested_resource.reset_cache_keys
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Cache keys cleared')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  def provision_raevo_ai
    stages = parsed_raevo_ai_stages!
    integration = raevo_ai_integration_for_provisioning!
    RaevoAi::IntegrationProvisioner.new(
      integration: integration,
      command_token: raevo_ai_provisioning_params[:command_token]
    ).provision!(
      board_key: raevo_ai_provisioning_params[:board_key],
      board_id: raevo_ai_provisioning_params[:board_id],
      initial_stage_id: raevo_ai_provisioning_params[:initial_stage_id],
      stages: stages,
      ai_tab_board_ids: [raevo_ai_provisioning_params[:board_id]]
    )

    redirect_to [namespace, requested_resource], notice: t('super_admin.raevo_ai.provisioned')
  rescue RaevoAi::IntegrationProvisioner::InvalidProvisioning,
         RaevoAi::CrmCatalogPublisher::InvalidCatalog, RaevoAi::OpportunityAiTabProvisioner::InvalidBoard
    redirect_to [namespace, requested_resource], alert: t('super_admin.raevo_ai.provisioning_failed')
  end

  def update_raevo_ai_stage_mapping
    integration = requested_resource.raevo_ai_integration
    raise RaevoAi::IntegrationProvisioner::InvalidProvisioning, 'integration is not provisioned' unless integration

    RaevoAi::IntegrationProvisioner.new(integration: integration).reconfigure!(
      board_key: raevo_ai_provisioning_params[:board_key],
      board_id: raevo_ai_provisioning_params[:board_id],
      initial_stage_id: raevo_ai_provisioning_params[:initial_stage_id],
      stages: parsed_raevo_ai_stages!,
      ai_tab_board_ids: [raevo_ai_provisioning_params[:board_id]]
    )

    redirect_to [namespace, requested_resource], notice: t('super_admin.raevo_ai.stage_mapping_updated')
  rescue RaevoAi::IntegrationProvisioner::InvalidProvisioning,
         RaevoAi::CrmCatalogPublisher::InvalidCatalog, RaevoAi::OpportunityAiTabProvisioner::InvalidBoard
    redirect_to [namespace, requested_resource], alert: t('super_admin.raevo_ai.stage_mapping_update_failed')
  end

  def update_raevo_ai_handoff
    integration = requested_resource.raevo_ai_integration
    raise RaevoAi::HandoffConfigurator::InvalidConfiguration, 'integration is not provisioned' unless integration

    RaevoAi::HandoffConfigurator.new(integration: integration).configure!(
      team_id: raevo_ai_provisioning_params[:handoff_team_id],
      assignee_id: raevo_ai_provisioning_params[:handoff_assignee_id],
      allowed_inbox_ids: raevo_ai_provisioning_params[:handoff_allowed_inbox_ids],
      labels: raevo_ai_provisioning_params[:handoff_labels]
    )
    redirect_to [namespace, requested_resource], notice: t('super_admin.raevo_ai.handoff_updated')
  rescue RaevoAi::HandoffConfigurator::InvalidConfiguration
    redirect_to [namespace, requested_resource], alert: t('super_admin.raevo_ai.handoff_update_failed')
  end

  def activate_raevo_ai
    unless ActiveModel::Type::Boolean.new.cast(params[:token_deployed])
      return redirect_to [namespace, requested_resource], alert: t('super_admin.raevo_ai.token_not_deployed')
    end

    integration = requested_resource.raevo_ai_integration
    raise RaevoAi::IntegrationProvisioner::InvalidProvisioning, 'integration is not provisioned' unless integration

    RaevoAi::IntegrationProvisioner.new(integration: integration).activate!(actor_ref: "super_admin:#{current_super_admin.id}")

    redirect_to [namespace, requested_resource], notice: t('super_admin.raevo_ai.activated')
  rescue RaevoAi::IntegrationProvisioner::InvalidProvisioning
    redirect_to [namespace, requested_resource], alert: t('super_admin.raevo_ai.not_provisioned')
  end

  def rotate_raevo_ai_command_token
    unless ActiveModel::Type::Boolean.new.cast(raevo_ai_provisioning_params[:token_deployed])
      return redirect_to [namespace, requested_resource], alert: t('super_admin.raevo_ai.token_not_deployed')
    end

    integration = requested_resource.raevo_ai_integration
    raise RaevoAi::IntegrationProvisioner::InvalidProvisioning, 'integration is not active' unless integration

    RaevoAi::IntegrationProvisioner.new(
      integration: integration,
      command_token: raevo_ai_provisioning_params[:command_token]
    ).rotate_command_token!(actor_ref: "super_admin:#{current_super_admin.id}")

    redirect_to [namespace, requested_resource], notice: t('super_admin.raevo_ai.command_token_rotated')
  rescue RaevoAi::IntegrationProvisioner::InvalidProvisioning
    redirect_to [namespace, requested_resource], alert: t('super_admin.raevo_ai.command_token_rotation_failed')
  end

  def destroy
    account = Account.find(params[:id])

    DeleteObjectJob.perform_later(account) if account.present?
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Account deletion is in progress.')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  private

  def raevo_ai_integration_for_provisioning!
    integration = requested_resource.raevo_ai_integration
    return requested_resource.create_raevo_ai_integration!(clinic_id: raevo_ai_provisioning_params[:clinic_id], enabled: false) unless integration

    return integration if integration.clinic_id == raevo_ai_provisioning_params[:clinic_id]

    raise RaevoAi::IntegrationProvisioner::InvalidProvisioning, 'clinic_id cannot change after integration creation'
  end

  def raevo_ai_provisioning_params
    params.require(:raevo_ai).permit(
      :clinic_id, :command_token, :board_key, :board_id, :initial_stage_id, :token_deployed,
      :handoff_team_id, :handoff_assignee_id, :handoff_labels,
      handoff_allowed_inbox_ids: [],
      stage_mappings: SEMANTIC_STAGE_EVENTS.keys
    )
  end

  def parsed_raevo_ai_stages!
    stage_mappings = raevo_ai_provisioning_params.fetch(:stage_mappings, {}).to_h.stringify_keys
    missing_events = SEMANTIC_STAGE_EVENTS.keys - stage_mappings.keys
    invalid_events = stage_mappings.values.any?(&:blank?)
    raise RaevoAi::IntegrationProvisioner::InvalidProvisioning, 'each semantic stage must be mapped' if missing_events.any? || invalid_events

    SEMANTIC_STAGE_EVENTS.to_h do |event_key, allowed_from|
      [event_key, { 'stage_id' => stage_mappings.fetch(event_key), 'allowed_from' => allowed_from }]
    end
  end
end

SuperAdmin::AccountsController.prepend_mod_with('SuperAdmin::AccountsController')
