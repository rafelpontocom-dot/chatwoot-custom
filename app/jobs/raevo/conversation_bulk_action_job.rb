# RAEVO (17/10, 123jpnbcxh4) — aplica uma ação a muitas conversas.
#
# O que o Chatwoot já faz em lote (estado, adiar, agente, time, etiquetas) passa
# pelo `BulkActionsJob` nativo, para não haver duas maneiras de resolver uma
# conversa. O resto — prioridade, lida, não lida e excluir — o nativo só faz uma
# a uma, e faz-se aqui com as mesmas regras dos endpoints de uma conversa.
class Raevo::ConversationBulkActionJob < ApplicationJob
  queue_as :medium

  NATIVE = %w[resolve pending reopen snooze add_labels remove_labels assign_agent assign_team].freeze
  STATUS = { 'resolve' => 'resolved', 'pending' => 'pending', 'reopen' => 'open', 'snooze' => 'snoozed' }.freeze

  def perform(account, user, display_ids, operation, value = nil)
    return if display_ids.blank?

    @account = account
    @user = user
    @display_ids = display_ids
    @value = value
    NATIVE.include?(operation) ? native(operation) : send(:"apply_#{operation}")
  end

  private

  # `priority` e companhia levam prefixo: `ActiveJob::Base#priority` existe e é
  # chamado ao enfileirar.
  def apply_priority
    each_conversation { |conversation| conversation.update!(priority: @value) }
  end

  def apply_read
    each_conversation { |conversation| mark_seen(conversation, Time.current) }
  end

  def apply_unread
    each_conversation do |conversation|
      last_incoming = conversation.messages.incoming.last
      mark_seen(conversation, last_incoming && (last_incoming.created_at - 1.second))
    end
  end

  def apply_delete
    each_conversation { |conversation| Conversations::DeleteService.new(conversation: conversation, user: @user).perform }
  end

  def native(operation)
    params = { type: 'Conversation', ids: @display_ids }.merge(native_change(operation))
    ::BulkActionsJob.perform_now(account: @account, user: @user, params: params.with_indifferent_access)
  end

  def native_change(operation)
    return { fields: { status: STATUS[operation] } }.merge(snooze_until(operation)) if STATUS.key?(operation)

    {
      'assign_agent' => { fields: { assignee_id: @value } },
      'assign_team' => { fields: { team_id: @value } },
      'add_labels' => { labels: { add: Array(@value) } },
      'remove_labels' => { labels: { remove: Array(@value) } }
    }.fetch(operation)
  end

  def snooze_until(operation)
    operation == 'snooze' && @value.present? ? { snoozed_until: @value } : {}
  end

  def each_conversation(&)
    scope = @account.conversations.where(display_id: @display_ids)
    Conversations::PermissionFilterService.new(scope, @user, @account).perform.find_each(&)
  end

  # Como `ConversationsController#update_last_seen_on_conversation`: sem callbacks,
  # e com os contadores de não lidas avisados.
  def mark_seen(conversation, seen_at)
    updates = { agent_last_seen_at: seen_at }
    updates[:assignee_last_seen_at] = seen_at if conversation.assignee_id == @user.id
    conversation.update_columns(updates) # rubocop:disable Rails/SkipsModelValidations
    ::Conversations::UnreadCounts::Notifier.new(conversation).perform
    ::Conversations::UnreadCounts::FilteredCountInvalidator.new(@account).conversation_changed!
  end
end
