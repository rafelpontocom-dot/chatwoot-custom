class Public::Api::V1::RaevoAi::CrmCommandsController < ActionController::API
  before_action :authenticate_integration!
  before_action :enforce_rate_limit!

  def fields
    render json: RaevoAi::CrmFieldExecutor.new(
      integration: @integration, card: resolved_card(fields_params[:board_key]), command: {
        action_id: fields_params[:action_id], board_key: fields_params[:board_key],
        expected_lock_version: fields_params[:expected_lock_version].to_i, fields: fields_params[:fields].map(&:to_h)
      }
    ).perform
  rescue *crm_errors => e
    render json: { error: e.class.name.demodulize.underscore }, status: crm_status(e)
  end

  def opportunities
    conversation = @integration.account.conversations.find_by!(display_id: opportunity_params[:conversation_id])
    render json: RaevoAi::CrmOpportunityExecutor.new(
      integration: @integration,
      conversation: conversation,
      command: { action_id: opportunity_params[:action_id], board_key: opportunity_params[:board_key] }
    ).perform
  rescue *crm_errors => e
    render json: { error: e.class.name.demodulize.underscore }, status: crm_status(e)
  end

  def stages
    render json: RaevoAi::CrmStageExecutor.new(
      integration: @integration, card: resolved_card(stage_params[:board_key]), command: {
        action_id: stage_params[:action_id], board_key: stage_params[:board_key], event_key: stage_params[:event_key],
        expected_lock_version: stage_params[:expected_lock_version].to_i
      }
    ).perform
  rescue *crm_errors => e
    render json: { error: e.class.name.demodulize.underscore }, status: crm_status(e)
  end

  def labels
    render json: RaevoAi::CrmLabelExecutor.new(
      integration: @integration, card: resolved_card(label_params[:board_key]), command: {
        action_id: label_params[:action_id], board_key: label_params[:board_key],
        expected_lock_version: label_params[:expected_lock_version].to_i, label: label_params[:label]
      }
    ).perform
  rescue *crm_errors => e
    render json: { error: e.class.name.demodulize.underscore }, status: crm_status(e)
  end

  def contact_name
    conversation = @integration.account.conversations.find_by!(display_id: contact_name_params[:conversation_id])
    render json: RaevoAi::CrmContactNameExecutor.new(
      integration: @integration, contact: conversation.contact, command: {
        action_id: contact_name_params[:action_id], name: contact_name_params[:name]
      }
    ).perform
  rescue *crm_errors => e
    render json: { error: e.class.name.demodulize.underscore }, status: crm_status(e)
  end

  def context
    render json: { lock_version: resolved_card(context_params[:board_key]).lock_version }
  rescue *crm_errors => e
    render json: { error: e.class.name.demodulize.underscore }, status: crm_status(e)
  end

  private

  def authenticate_integration!
    @integration = RaevoAi::CommandAuthenticator.new(
      clinic_id: request.headers['X-Raevo-Clinic-Id'], token: request.headers['X-Raevo-Command-Token']
    ).authenticate
    render json: { error: 'unauthorized' }, status: :unauthorized unless @integration
  end

  def enforce_rate_limit!
    return if RaevoAi::CommandRateLimiter.new(integration: @integration).allowed?

    render json: { error: 'rate_limited' }, status: :too_many_requests
  end

  def resolved_card(board_key)
    catalog = RaevoAi::CrmCatalog.new(integration: @integration)
    conversation = @integration.account.conversations.find_by!(display_id: params[:conversation_id])
    RaevoAi::CrmCardResolver.new(integration: @integration, conversation: conversation, board: catalog.resolve_board!(board_key)).resolve!
  end

  def fields_params
    @fields_params ||= params.permit(:action_id, :conversation_id, :board_key, :expected_lock_version, fields: %i[key value]).tap do |permitted|
      %i[action_id conversation_id board_key expected_lock_version fields].each { |key| permitted.require(key) }
    end
  end

  def opportunity_params
    @opportunity_params ||= params.permit(:action_id, :conversation_id, :board_key).tap do |permitted|
      %i[action_id conversation_id board_key].each { |key| permitted.require(key) }
    end
  end

  def stage_params
    @stage_params ||= params.permit(:action_id, :conversation_id, :board_key, :event_key, :expected_lock_version).tap do |permitted|
      %i[action_id conversation_id board_key event_key expected_lock_version].each { |key| permitted.require(key) }
    end
  end

  def context_params
    @context_params ||= params.permit(:conversation_id, :board_key).tap do |permitted|
      %i[conversation_id board_key].each { |key| permitted.require(key) }
    end
  end

  def label_params
    @label_params ||= params.permit(:action_id, :conversation_id, :board_key, :expected_lock_version, :label).tap do |permitted|
      %i[action_id conversation_id board_key expected_lock_version label].each { |key| permitted.require(key) }
    end
  end

  def contact_name_params
    @contact_name_params ||= params.permit(:action_id, :conversation_id, :name).tap do |permitted|
      %i[action_id conversation_id name].each { |key| permitted.require(key) }
    end
  end

  def crm_errors
    [ActiveRecord::RecordNotFound, RaevoAi::CrmCardResolver::AmbiguousCard, RaevoAi::CrmCatalog::InvalidCatalog,
     RaevoAi::CrmCatalog::TransitionNotAllowed, RaevoAi::CrmFieldExecutor::InvalidCard, RaevoAi::CrmFieldExecutor::InvalidValue,
     RaevoAi::CrmFieldExecutor::LockConflict, RaevoAi::CrmStageExecutor::InvalidCard, RaevoAi::CrmStageExecutor::LockConflict,
     RaevoAi::CrmLabelExecutor::InvalidCard, RaevoAi::CrmLabelExecutor::LockConflict,
     RaevoAi::CrmOpportunityExecutor::InvalidConversation,
     RaevoAi::CrmContactNameExecutor::InvalidContact,
     RaevoAi::CommandRecorder::Conflict]
  end

  def crm_status(error)
    return :conflict if error.is_a?(RaevoAi::CommandRecorder::Conflict) || error.class.name.end_with?('LockConflict')
    return :not_found if error.is_a?(ActiveRecord::RecordNotFound)

    :unprocessable_entity
  end
end
