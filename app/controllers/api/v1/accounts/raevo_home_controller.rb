class Api::V1::Accounts::RaevoHomeController < Api::V1::Accounts::BaseController
  MAX_ITEMS = 8
  CARD_CANDIDATE_LIMIT = 50

  before_action :authorize_home

  # A secretaria escolhe o que ver: por caixa de entrada, por funil, e em que
  # ordem — quem espera há mais tempo ou o que chegou agora.
  CONVERSATION_SORTS = %w[waiting recent].freeze
  ACTION_SORTS = %w[overdue recent].freeze

  def show
    conversations = open_conversations

    render json: {
      open_conversations_count: conversations[:count],
      open_conversations: conversations[:items],
      overdue_actions: overdue_actions,
      filters: {
        inboxes: inbox_options,
        boards: board_options,
        conversation_sort: conversation_sort,
        action_sort: action_sort,
        inbox_id: selected_inbox_id,
        board_id: selected_board_id
      }
    }
  end

  private

  def authorize_home
    authorize KanbanBoard.new(account: Current.account), :index?
  end

  LAST_MESSAGE_LIMIT = 140

  def conversation_sort
    CONVERSATION_SORTS.include?(params[:conversation_sort]) ? params[:conversation_sort] : 'waiting'
  end

  def action_sort
    ACTION_SORTS.include?(params[:action_sort]) ? params[:action_sort] : 'overdue'
  end

  def selected_inbox_id
    return if params[:inbox_id].blank?

    Current.account.inboxes.where(id: params[:inbox_id]).pick(:id)
  end

  def selected_board_id
    return if params[:board_id].blank?

    policy_scope(KanbanBoard).where(id: params[:board_id]).pick(:id)
  end

  def inbox_options
    Current.user.assigned_inboxes.where(account_id: Current.account.id).order(:name).map { |inbox| { id: inbox.id, name: inbox.name } }
  end

  def board_options
    policy_scope(KanbanBoard).active.order(:name).map { |board| { id: board.id, name: board.name } }
  end

  def open_conversations
    finder_params = { status: 'open', sort_by: 'unread', page: 1 }
    finder_params[:inbox_id] = selected_inbox_id if selected_inbox_id
    result = ConversationFinder.new(Current.user, finder_params).perform
    # Por omissão, quem espera há mais tempo aparece primeiro: a Home existe
    # para mostrar o que está parado, não a ordem em que o banco devolveu.
    ordered = result[:conversations].sort_by { |conversation| conversation.last_activity_at || Time.zone.at(0) }
    ordered = ordered.reverse if conversation_sort == 'recent'
    conversations = ordered.first(MAX_ITEMS)

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
    board_ids = selected_board_id ? [selected_board_id] : policy_scope(KanbanBoard).pluck(:id)
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
              .order(next_action_at: action_sort == 'recent' ? :desc : :asc, id: :asc)
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
