class RaevoAi::CrmCardResolver
  class AmbiguousCard < StandardError; end

  def initialize(integration:, conversation:, board:)
    @integration = integration
    @conversation = conversation
    @board = board
  end

  def resolve!
    cards = @board.kanban_cards.active.where(account_id: @integration.account_id, conversation_id: @conversation.id).to_a
    raise ActiveRecord::RecordNotFound if cards.empty?
    raise AmbiguousCard, 'multiple active cards are linked to the conversation' if cards.many?

    cards.first
  end
end
