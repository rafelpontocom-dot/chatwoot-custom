class KanbanBoards::SalesSummaryBuilder
  def initialize(kanban_board)
    @kanban_board = kanban_board
  end

  def call
    cards = kanban_board.kanban_cards.active.includes(:kanban_stage, :owner).to_a
    open_cards = open_sales_cards(cards)
    won_cards = won_sales_cards(cards)
    lost_cards = lost_sales_cards(cards)

    {
      open_count: open_cards.count,
      won_count: won_cards.count,
      lost_count: lost_cards.count,
      overdue_count: overdue_sales_cards(cards).count,
      stale_count: cards.count(&:stale_in_stage?),
      open_amount_cents: sales_amount_cents(open_cards),
      won_amount_cents: sales_amount_cents(won_cards),
      lost_amount_cents: sales_amount_cents(lost_cards),
      by_stage: sales_summary_by_stage(cards),
      by_owner: sales_summary_by_owner(cards),
      lost_reasons: sales_summary_lost_reasons(cards),
      agenda: sales_action_agenda(cards)
    }
  end

  private

  attr_reader :kanban_board

  def open_sales_cards(cards)
    cards.select(&:open_opportunity?)
  end

  def won_sales_cards(cards)
    cards.select { |card| card.won_at.present? }
  end

  def lost_sales_cards(cards)
    cards.select { |card| card.lost_at.present? }
  end

  def overdue_sales_cards(cards)
    cards.select { |card| card.next_action_status == KanbanCard::NEXT_ACTION_STATUS_OVERDUE }
  end

  def sales_amount_cents(cards)
    cards.sum { |card| card.amount_cents.to_i }
  end

  def sales_summary_by_stage(cards)
    kanban_board.kanban_stages.active.ordered.map do |stage|
      stage_cards = cards.select { |card| card.kanban_stage_id == stage.id }
      sales_summary_bucket(id: stage.id, name: stage.name, cards: stage_cards)
    end
  end

  def sales_summary_by_owner(cards)
    cards.select(&:owner_id).group_by(&:owner).map do |owner, owner_cards|
      sales_summary_bucket(id: owner.id, name: owner.name, cards: owner_cards)
    end
  end

  def sales_summary_lost_reasons(cards)
    cards.select { |card| card.lost_at.present? && card.lost_reason.present? }
         .group_by(&:lost_reason)
         .map do |reason, reason_cards|
      {
        reason: reason,
        count: reason_cards.count,
        amount_cents: sales_amount_cents(reason_cards)
      }
    end
  end

  def sales_action_agenda(cards)
    agenda_items = cards.filter_map do |card|
      status = card.next_action_status
      next unless [KanbanCard::NEXT_ACTION_STATUS_OVERDUE, KanbanCard::NEXT_ACTION_STATUS_DUE_TODAY].include?(status)

      {
        id: card.id,
        subject: card.subject.presence || card.contact.name,
        next_action_type: card.next_action_type,
        next_action_at: card.next_action_at&.iso8601,
        status: status,
        owner_id: card.owner_id,
        owner_name: card.owner&.name
      }
    end

    agenda_items.sort_by { |item| item[:next_action_at].to_s }
  end

  def sales_summary_bucket(id:, name:, cards:)
    {
      id: id,
      name: name,
      open_count: cards.count(&:open_opportunity?),
      won_count: cards.count { |card| card.won_at.present? },
      lost_count: cards.count { |card| card.lost_at.present? },
      amount_cents: sales_amount_cents(cards),
      overdue_count: overdue_sales_cards(cards).count,
      stale_count: cards.count(&:stale_in_stage?)
    }
  end
end
