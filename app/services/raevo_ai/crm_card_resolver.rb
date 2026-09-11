class RaevoAi::CrmCardResolver
  class AmbiguousCard < StandardError; end

  def initialize(integration:, conversation:, board:)
    @integration = integration
    @conversation = conversation
    @board = board
  end

  def resolve!
    conversation_cards = @board.kanban_cards.active.where(account_id: @integration.account_id, conversation_id: @conversation.id).to_a
    raise AmbiguousCard, 'multiple active cards are linked to the conversation' if conversation_cards.many?

    return conversation_cards.first if conversation_cards.one?

    contact_cards = @board.kanban_cards.open_opportunities
                          .where(account_id: @integration.account_id, contact_id: @conversation.contact_id)
                          .to_a
    raise ActiveRecord::RecordNotFound if contact_cards.empty?
    raise AmbiguousCard, 'multiple open cards belong to the conversation contact' if contact_cards.many?

    contact_cards.first
  end
end
