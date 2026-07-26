class KanbanAutomations::DispatchOverdueNextActionsService
  BATCH_SIZE = 100

  def initialize(now: Time.current)
    @now = now
  end

  def perform!
    overdue_cards.find_each(batch_size: BATCH_SIZE) { |card| dispatch_rules_for(card) }
  end

  private

  attr_reader :now

  def overdue_cards
    KanbanCard.open_opportunities.where.not(next_action_at: nil)
              .where('next_action_at < ?', now)
              .where(next_action_completed_at: nil)
  end

  def dispatch_rules_for(card)
    KanbanAutomationRule.active.where(
      account_id: card.account_id,
      kanban_board_id: card.kanban_board_id,
      event_name: Events::Types::KANBAN_CARD_NEXT_ACTION_OVERDUE
    ).find_each do |rule|
      KanbanAutomations::ExecuteRuleJob.perform_later(
        rule.id,
        Events::Types::KANBAN_CARD_NEXT_ACTION_OVERDUE,
        "next-action-overdue:#{card.id}:#{now.to_date.iso8601}",
        card.id
      )
    end
  end
end
