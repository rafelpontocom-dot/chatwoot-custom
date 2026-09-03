class Marketing::StampCardAttributionService
  # Escreve a atribuicao nos campos da aba Marketing da oportunidade.
  #
  # Uma vez, no nascimento do card, e nunca por cima de valor que ja exista.
  # Duas razoes: quem digitou a origem a mao continua a mandar, e os workflows
  # de n8n podem seguir escrevendo enquanto ainda sao a fonte — durante a
  # transicao eles ganham, que e o certo enquanto forem autoridade.
  #
  # Chave que o quadro nao configurou e descartada pelo proprio KanbanCard, o
  # que torna isto seguro num quadro sem o preset de Marketing.
  def initialize(kanban_card:)
    @kanban_card = kanban_card
  end

  def perform
    return if kanban_card.blank? || attribution.blank?

    kanban_card.with_lock do
      current = kanban_card.custom_field_values.to_h.stringify_keys
      additions = Marketing::AttributionFields.card_values(attribution).reject { |key, _| current[key].present? }
      next if additions.blank?

      kanban_card.update!(custom_field_values: current.merge(additions))
    end
  end

  private

  attr_reader :kanban_card

  # A conversa que deu origem ao card e a resposta mais precisa; o contato e o
  # que sobra quando o card nasceu sem conversa, como no formulario publico.
  def attribution
    @attribution ||= conversation_touchpoint&.payload.presence || contact_attribution
  end

  def conversation_touchpoint
    return if kanban_card.conversation_id.blank?

    MarketingTouchpoint
      .where(account_id: kanban_card.account_id, conversation_id: kanban_card.conversation_id)
      .recent_first
      .first
  end

  def contact_attribution
    stored = kanban_card.contact&.additional_attributes.to_h[Marketing::RecordTouchpointService::ATTRIBUTION_KEY].to_h
    stored['last_touch'].presence || stored['first_touch'].presence || {}
  end
end
