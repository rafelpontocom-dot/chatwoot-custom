class Api::V1::Accounts::RaevoHomeController < Api::V1::Accounts::BaseController
  include RaevoHomeCards

  MAX_ITEMS = 8
  # Quantas ações atrasadas se examinam para dar o total do emblema. Acima disto o
  # número passa a «mais de», em vez de mentir por baixo.
  OVERDUE_COUNT_LIMIT = 200

  before_action :authorize_home

  # A secretaria escolhe o que ver: por caixa de entrada, por funil, e em que
  # ordem — quem espera há mais tempo ou o que chegou agora.
  CONVERSATION_SORTS = %w[waiting recent].freeze
  ACTION_SORTS = %w[overdue recent].freeze

  # `waiting` ordena por `waiting_since`, não por `last_activity_at`. A segunda mexe
  # quando *qualquer um* age, incluindo quando somos nós a responder, e poria no topo
  # de «quem espera há mais tempo» uma conversa acabada de responder. `waiting_since`
  # é posto quando o contacto escreve e limpo quando a clínica responde: presente
  # significa que a bola está connosco, que é a pergunta que esta tela faz.
  CONVERSATION_SORT_KEYS = { 'waiting' => 'waiting_since_asc', 'recent' => 'last_activity_at_desc' }.freeze

  # O período limita as duas listas longas: conversas pela atividade, ações pela
  # data em que venceram. A agenda é sempre hoje, e cobranças e paradas são por
  # natureza «tudo o que está em atraso» — o período não lhes acrescenta nada.
  PERIODS = { 'today' => 1.day, '7d' => 7.days, '30d' => 30.days }.freeze

  def show
    render json: payload
  end

  private

  def payload
    conversations = open_conversations
    actions = overdue_actions

    {
      open_conversations_count: conversations[:count],
      open_conversations: conversations[:items],
      overdue_actions_count: actions[:count],
      overdue_actions_count_capped: actions[:count_capped],
      overdue_actions: actions[:items],
      today_appointments: today_appointments,
      overdue_payments: overdue_payments,
      stale_opportunities: stale_opportunities,
      filters: filter_options
    }
  end

  def filter_options
    {
      inboxes: inbox_options,
      boards: board_options,
      conversation_sort: conversation_sort,
      action_sort: action_sort,
      period: period,
      inbox_id: selected_inbox_id,
      board_id: selected_board_id
    }
  end

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

  def period
    PERIODS.key?(params[:period]) ? params[:period] : nil
  end

  def period_cutoff
    PERIODS[period]&.ago
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

  # A ordenação é feita pela base de dados, sobre todas as conversas abertas. Ordenar
  # em Ruby só reordenava a primeira página do finder (25 por omissão), e acima disso
  # quem esperava há mais tempo podia ficar na página 2 e nunca aparecer.
  def open_conversations
    finder_params = { status: 'open', sort_by: CONVERSATION_SORT_KEYS.fetch(conversation_sort), page: 1 }
    finder_params[:inbox_id] = selected_inbox_id if selected_inbox_id
    finder_params[:updated_within] = PERIODS[period].to_i if period
    result = ConversationFinder.new(Current.user, finder_params).perform

    {
      count: result[:count][:all_count],
      items: result[:conversations].first(MAX_ITEMS).map { |conversation| open_conversation_payload(conversation) }
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

  # O emblema mostra o total, não o comprimento da lista cortada. Contar depois da
  # policy é obrigatório: um agente pode ver o quadro e não ver a conversa do cartão.
  def overdue_actions
    board_ids = selected_board_id ? [selected_board_id] : policy_scope(KanbanBoard).pluck(:id)
    return { count: 0, count_capped: false, items: [] } if board_ids.empty?

    # O tecto mede-se nos candidatos carregados, não nos que sobreviveram à policy:
    # se 200 vieram e só 150 passaram, há provavelmente mais para lá da janela.
    candidates = overdue_card_candidates(board_ids).to_a
    visible = candidates.select { |card| policy(card).show? }

    {
      count: visible.size,
      count_capped: candidates.size >= OVERDUE_COUNT_LIMIT,
      items: visible.first(MAX_ITEMS).map { |card| overdue_action_payload(card) }
    }
  end

  def overdue_card_candidates(board_ids)
    KanbanCard.active
              .where(account_id: Current.account.id, kanban_board_id: board_ids, won_at: nil, lost_at: nil,
                     next_action_completed_at: nil)
              .where.not(next_action_at: nil)
              .where('next_action_at < ?', Time.current)
              .then { |scope| period_cutoff ? scope.where('next_action_at >= ?', period_cutoff) : scope }
              .includes(:contact, :kanban_board, :kanban_stage, :owner, :conversation, :inbox)
              .order(next_action_at: action_sort == 'recent' ? :desc : :asc, id: :asc)
              .limit(OVERDUE_COUNT_LIMIT)
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
