# RAEVO (17/10, 123jpnbcxh4) — ações em massa nas Conversas: as marcadas, ou todas
# as do filtro. Ver `Raevo::ConversationSelection` e `Raevo::ConversationBulkActionJob`.
class Api::V1::Accounts::RaevoConversationBulkActionsController < Api::V1::Accounts::BaseController
  OPERATIONS = %w[resolve pending reopen snooze priority read unread add_labels remove_labels assign_agent assign_team delete].freeze

  before_action :validate_operation, only: :create

  def count
    render json: { count: selection.count }
  end

  def create
    authorize Conversation, :destroy? if operation == 'delete'

    display_ids = selection.display_ids
    skipped = 0
    display_ids, skipped = without_missing_required_attributes(display_ids) if operation == 'resolve'
    Raevo::ConversationBulkActionJob.perform_later(Current.account, Current.user, display_ids, operation, value)
    render json: { count: display_ids.size, skipped: skipped }, status: :accepted
  end

  private

  def operation
    params[:operation].to_s
  end

  def value
    case operation
    when 'priority', 'snooze' then params[:value].presence
    when 'add_labels', 'remove_labels' then Array(params[:value]).map(&:to_s)
    when 'assign_agent', 'assign_team' then params[:value].presence&.to_i
    end
  end

  def validate_operation
    raise ActionController::ParameterMissing, :operation unless OPERATIONS.include?(operation)
    return unless operation == 'priority' && value && !Conversation.priorities.key?(value)

    raise ActionController::ParameterMissing, :value
  end

  def selection
    @selection ||= Raevo::ConversationSelection.new(account: Current.account, user: Current.user, scope: scope_params)
  end

  def scope_params
    params.require(:scope).permit(
      ids: [],
      filters: [:inbox_id, :team_id, :status, :assignee_type, :conversation_type, :sort_by, { labels: [] }],
      query: [:attribute_key, :filter_operator, :query_operator, :attribute_model, :custom_attribute_type, { values: [] }]
    )
  end

  # Como o «Resolver» de uma conversa: com atributos obrigatórios em falta, a
  # conversa fica de fora e o total diz quantas.
  def without_missing_required_attributes(display_ids)
    required = required_attribute_keys
    return [display_ids, 0] if required.empty?

    ready = Current.account.conversations.where(display_id: display_ids).select do |conversation|
      required.all? { |key| conversation.custom_attributes.to_h[key].present? }
    end.map(&:display_id)
    [ready, display_ids.size - ready.size]
  end

  def required_attribute_keys
    return [] unless Current.account.feature_enabled?('conversation_required_attributes')

    Current.account.settings.to_h['conversation_required_attributes'] || []
  end
end
