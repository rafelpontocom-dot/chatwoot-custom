class MarketingListener < BaseListener
  # A conversa nasce com a URL da pagina de onde veio; a oportunidade nasce
  # depois. Os dois momentos sao os dois metodos abaixo.

  def conversation_created(event)
    conversation = event.data[:conversation]
    return if conversation.blank?

    attribution = Marketing::UrlAttributionParser.new(url: referer_for(conversation)).perform
    # `custom_attributes` e a ponte para quem injeta atribuicao de fora — hoje
    # um passo de n8n, amanha o proprio WAHA se expuser o dado do anuncio.
    attribution = attribution.presence || injected_attribution(conversation)
    return if attribution.blank?

    Marketing::RecordTouchpointService.new(
      account: conversation.account,
      source: injected?(conversation) && attribution.present? ? 'api_attribute' : 'widget_referer',
      attribution: attribution,
      contact: conversation.contact,
      conversation: conversation,
      occurred_at: conversation.created_at,
      dedupe_parts: ['conversation', conversation.id]
    ).perform
  end

  def kanban_card_created(event)
    card_id = event.data.with_indifferent_access[:card_id]
    return if card_id.blank?

    Marketing::StampCardAttributionService.new(kanban_card: KanbanCard.find_by(id: card_id)).perform
  end

  private

  # O widget manda a URL completa da pagina anfitria, com query string. O
  # Conversation ja a validou como URL antes de guardar.
  def referer_for(conversation)
    conversation.additional_attributes.to_h['referer']
  end

  def injected_attribution(conversation)
    Marketing::AttributionFields.normalize(
      conversation.custom_attributes.to_h[Marketing::RecordTouchpointService::ATTRIBUTION_KEY]
    )
  end

  def injected?(conversation)
    conversation.custom_attributes.to_h.key?(Marketing::RecordTouchpointService::ATTRIBUTION_KEY)
  end
end
