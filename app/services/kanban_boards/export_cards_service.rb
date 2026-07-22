require 'csv'

class KanbanBoards::ExportCardsService
  MAX_CARDS = 10_000
  SORT_METHODS = {
    'next_action_asc' => :next_action_sort_key,
    'created_desc' => :created_sort_key,
    'amount_desc' => :amount_sort_key,
    'stage_time_desc' => :stage_time_sort_key
  }.freeze

  def initialize(account:, user:, board:, filters: {})
    @account = account
    @user = user
    @board = board
    @filters = filters
  end

  def call
    CSV.generate(headers: true) do |csv|
      csv << headers
      cards.each { |card| csv << row_for(card) }
    end
  end

  private

  attr_reader :account, :user, :board, :filters

  def cards
    stage_cards = board.kanban_stages.active.ordered.flat_map do |stage|
      cards_for_stage(stage)
    end
    @cards ||= sort_cards(stage_cards)
  end

  def cards_for_stage(stage)
    cards = []
    cursor = nil

    loop do
      result = fetch_stage_cards(stage, cursor)
      cards.concat(result.cards)
      break unless result.has_more && cards.length < MAX_CARDS

      cursor = result.next_cursor
    end

    cards.first(MAX_CARDS)
  end

  def fetch_stage_cards(stage, cursor)
    KanbanCards::VisibleStageCardsQuery.new(
      account: account,
      user: user,
      kanban_board: board,
      kanban_stage: stage,
      limit: KanbanCards::VisibleStageCardsQuery::MAX_LIMIT,
      cursor: cursor,
      filtered_inbox_ids: filters[:inbox_ids],
      filtered_assignee_ids: filters[:assignee_ids],
      filtered_next_action_status: filters[:next_action],
      filtered_opportunity_status: filters[:status],
      search: filters[:search],
      sort: filters[:sort],
      visible_inbox_ids: visible_inbox_ids,
      visible_team_ids: visible_team_ids,
      account_user: account_user
    ).call
  end

  def sort_cards(cards)
    sort_method = SORT_METHODS[filters[:sort]]
    return cards unless sort_method

    cards.sort_by { |card| send(sort_method, card) }
  end

  def next_action_sort_key(card)
    [card.next_action_at.nil? ? 1 : 0, card.next_action_at || Time.zone.at(0), card.id]
  end

  def created_sort_key(card)
    [-card.created_at.to_f, -card.id]
  end

  def amount_sort_key(card)
    [-card.amount_cents.to_i, card.id]
  end

  def stage_time_sort_key(card)
    [card.stage_entered_at || Time.zone.at(0), card.id]
  end

  def headers
    [
      'ID', 'Oportunidade', 'Contato', 'Telefone', 'E-mail', 'Etapa', 'Status', 'Responsável',
      'Valor em centavos', 'Moeda', 'Próxima ação', 'Data da próxima ação', 'Observação da próxima ação',
      'Data prevista de fechamento', 'Criada em'
    ] + custom_field_definitions.pluck('label')
  end

  def row_for(card)
    base_row_for(card) + custom_field_values_for(card)
  end

  def base_row_for(card)
    [
      card.id,
      card.subject.presence || card.contact.name,
      card.contact.name,
      card.contact.phone_number,
      card.contact.email,
      card.kanban_stage.name,
      card_status(card),
      card.owner&.name,
      card.amount_cents,
      card.amount_currency,
      card.next_action_type,
      card.next_action_at&.iso8601,
      card.next_action_note,
      card.expected_close_date,
      card.created_at.iso8601
    ]
  end

  def custom_field_values_for(card)
    custom_field_definitions.map { |definition| card.custom_field_values[definition['key']] }
  end

  def card_status(card)
    return 'Ganha' if card.won_at.present?
    return 'Perdida' if card.lost_at.present?

    'Aberta'
  end

  def custom_field_definitions
    @custom_field_definitions ||= board.configured_custom_field_definitions
  end

  def visible_inbox_ids
    @visible_inbox_ids ||= user.inboxes.where(account_id: account.id).pluck(:id)
  end

  def visible_team_ids
    @visible_team_ids ||= user.teams.where(account_id: account.id).pluck(:id)
  end

  def account_user
    @account_user ||= user.account_users.find_by(account_id: account.id)
  end
end
