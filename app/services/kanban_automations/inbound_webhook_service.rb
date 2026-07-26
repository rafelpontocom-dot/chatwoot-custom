class KanbanAutomations::InboundWebhookService
  def initialize(connection:, card_id:, event_key:)
    @connection = connection
    @card_id = card_id
    @event_key = event_key
  end

  def perform!
    target_card = card
    KanbanAutomationRule.active
                        .where(
                          account: connection.account,
                          kanban_board: connection.kanban_board,
                          event_name: Events::Types::KANBAN_CARD_WEBHOOK_RECEIVED
                        )
                        .find_each do |rule|
      next unless matching_connection?(rule)

      KanbanAutomations::ExecuteRuleJob.perform_later(
        rule.id,
        Events::Types::KANBAN_CARD_WEBHOOK_RECEIVED,
        event_key,
        target_card.id,
        { event_data: { connection_id: connection.id } }
      )
    end
  end

  private

  attr_reader :connection, :card_id, :event_key

  def card
    @card ||= connection.kanban_board.kanban_cards.active.find(card_id)
  end

  def matching_connection?(rule)
    connection_ids = Array(rule.trigger_conditions[:connection_ids]).filter_map do |value|
      Integer(value, exception: false)
    end
    connection_ids.blank? || connection_ids.include?(connection.id)
  end
end
