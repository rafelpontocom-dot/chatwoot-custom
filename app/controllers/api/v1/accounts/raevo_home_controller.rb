class Api::V1::Accounts::RaevoHomeController < Api::V1::Accounts::BaseController
  MAX_ITEMS = 8
  CARD_CANDIDATE_LIMIT = 50

  before_action :authorize_home

  def show
    conversations = open_conversations

    render json: {
      open_conversations_count: conversations[:count],
      open_conversations: conversations[:items],
      overdue_actions: overdue_actions
    }
  end

  private

  def authorize_home
    authorize KanbanBoard.new(account: Current.account), :index?
  end

  LAST_MESSAGE_LIMIT = 140

  def open_conversations
    result = ConversationFinder.new(Current.user, status: 'open', sort_by: 'unread', page: 1).perform
    # Quem espera há mais tempo aparece primeiro: a Home existe para mostrar o
    # que está parado, não a ordem em que o banco devolveu.
    conversations = result[:conversations]
                    .sort_by { |conversation| conversation.last_activity_at || Time.zone.at(0) }
                    .first(MAX_ITEMS)

    {
      count: result[:count][:all_count],
      items: conversations.map { |conversation| open_conversation_payload(conversation) }
    }
  end

  def open_conversation_payload(conversation)
    {
      id: conversation.id,
      display_id: conversation.display_id,
      contact_name: conversation.contact&.name,
      inbox_name: conversation.inbox&.name,
      last_message: last_message_preview(conversation),
      unread_count: conversation.unread_incoming_messages.count,
      last_activity_at: conversation.last_activity_at&.iso8601,
      priority: conversation.priority
    }
  end

  # O subtítulo da linha precisa dizer o que a pessoa falou. Sem isso a Home
  # repete o nome da caixa de entrada em todas as linhas e não informa nada.
  def last_message_preview(conversation)
    message = conversation.messages
                          .where(message_type: [:incoming, :outgoing])
                          .where.not(content: [nil, ''])
                          .order(created_at: :desc)
                          .first
    return nil if message.blank?

    message.content.to_s.squish.truncate(LAST_MESSAGE_LIMIT)
  end

  def overdue_actions
    board_ids = policy_scope(KanbanBoard).pluck(:id)
    return [] if board_ids.empty?

    overdue_card_candidates(board_ids).filter_map do |card|
      next unless policy(card).show?

      overdue_action_payload(card)
    end.first(MAX_ITEMS)
  end

  def overdue_card_candidates(board_ids)
    KanbanCard.active
              .where(account_id: Current.account.id, kanban_board_id: board_ids, won_at: nil, lost_at: nil,
                     next_action_completed_at: nil)
              .where.not(next_action_at: nil)
              .where('next_action_at < ?', Time.current)
              .includes(:contact, :kanban_board, :kanban_stage, :owner, :conversation, :inbox)
              .order(next_action_at: :asc, id: :asc)
              .limit(CARD_CANDIDATE_LIMIT)
  end

  def overdue_action_payload(card)
    {
      kanban_card_id: card.id,
      kanban_board_id: card.kanban_board_id,
      kanban_board_name: card.kanban_board.name,
      kanban_stage_name: card.kanban_stage.name,
      subject: card.subject.presence || card.contact.name,
      contact_name: card.contact.name,
      owner_name: card.owner&.name,
      next_action_at: card.next_action_at.iso8601,
      next_action_type: card.next_action_type
    }
  end
end
