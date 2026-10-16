# Quantas conversas por ler estão atribuídas a quem pede: é o que acende o ponto
# vermelho no ícone da guia (123jpnbcxh5).
#
# O critério de «por ler» é o do construtor nativo
# (Conversations::UnreadCounts::Builder): conversa aberta com mensagem recebida
# depois da última visita de um agente. As caixas são as que a pessoa vê.
class Raevo::UnreadMineCount
  def initialize(account:, user:)
    @account = account
    @user = user
  end

  def count
    conversations = Conversation.arel_table
    messages = Message.arel_table

    account.conversations.open
           .where(assignee_id: user.id, inbox_id: visible_inbox_ids)
           .joins(:messages)
           .merge(Message.incoming.reorder(nil))
           .where(messages: { account_id: account.id })
           .where(conversations[:agent_last_seen_at].eq(nil).or(messages[:created_at].gt(conversations[:agent_last_seen_at])))
           .distinct
           .count
  end

  private

  attr_reader :account, :user

  def visible_inbox_ids
    return account.inboxes.select(:id) if account.administrators.exists?(user.id)

    user.inboxes.where(account_id: account.id).select(:id)
  end
end
