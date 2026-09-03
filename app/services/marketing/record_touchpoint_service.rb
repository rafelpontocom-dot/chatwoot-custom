class Marketing::RecordTouchpointService
  # Guarda um toque e atualiza o primeiro/ultimo contato conhecido da pessoa.
  #
  # E a unica porta de escrita da atribuicao: widget, formulario, Lead Ads e
  # link proprio entram todos por aqui, e por isso o opt-in do modulo tambem e
  # verificado aqui — instalar este codigo nao muda nada para quem nao ativou.
  ATTRIBUTION_KEY = 'marketing_attribution'.freeze

  # rubocop:disable Metrics/ParameterLists
  def initialize(account:, source:, attribution:, contact: nil, conversation: nil, kanban_card: nil, occurred_at: nil,
                 dedupe_parts: nil)
    @account = account
    @source = source
    @attribution = attribution
    @contact = contact
    @conversation = conversation
    @kanban_card = kanban_card
    @occurred_at = occurred_at || Time.current
    @dedupe_parts = dedupe_parts
  end
  # rubocop:enable Metrics/ParameterLists

  def perform
    return if account.blank? || !module_enabled?

    values = normalized_attribution
    return if values.blank?

    touchpoint = create_touchpoint(values)
    update_contact_attribution(values) if contact.present?
    touchpoint
  end

  private

  attr_reader :account, :source, :contact, :conversation, :kanban_card, :occurred_at

  def module_enabled?
    account.marketing_module_setting&.enabled?
  end

  # A origem derivada entra junto com o resto: quem le o toque nao deve ter de
  # reinterpretar a taxonomia depois.
  def normalized_attribution
    @normalized_attribution ||= begin
      values = Marketing::AttributionFields.normalize(@attribution)
      values.present? ? values.merge(Marketing::DeriveLeadOriginService.new(values).perform) : values
    end
  end

  def create_touchpoint(values)
    MarketingTouchpoint.create!(
      account: account,
      contact: contact,
      conversation: conversation,
      kanban_card: kanban_card,
      source: source,
      payload: values,
      occurred_at: occurred_at,
      dedupe_digest: dedupe_digest(values)
    )
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
    # Chegar duas vezes e o caso normal com webhook; nao e erro.
    raise unless duplicate?(e)

    MarketingTouchpoint.find_by(account_id: account.id, dedupe_digest: dedupe_digest(values))
  end

  def duplicate?(error)
    error.is_a?(ActiveRecord::RecordNotUnique) ||
      error.record.errors.of_kind?(:dedupe_digest, :taken)
  end

  def dedupe_digest(values)
    @dedupe_digest ||= MarketingTouchpoint.digest_for(
      *(@dedupe_parts || [source, contact&.id, conversation&.id, values.sort.to_s])
    )
  end

  def update_contact_attribution(values)
    contact.with_lock do
      attributes = contact.additional_attributes.to_h
      stored = attributes[ATTRIBUTION_KEY].to_h
      stamp = occurred_at.iso8601

      # O primeiro toque escreve uma vez e nunca mais: e ele que responde
      # "de onde esta pessoa veio", e essa resposta nao muda.
      if stored['first_touch'].blank?
        stored['first_touch'] = values
        stored['first_touch_at'] = stamp
      end
      stored['last_touch'] = values
      stored['last_touch_at'] = stamp

      contact.update!(additional_attributes: attributes.merge(ATTRIBUTION_KEY => stored))
    end
  end
end
