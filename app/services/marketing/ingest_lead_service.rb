class Marketing::IngestLeadService
  # A porta unica de entrada de lead: landing page, n8n, parceiro — e, quando
  # chegar, o Meta Lead Ads por dentro.
  #
  # Idempotencia nao e opcional: n8n repete, pagina e recarregada, plataforma
  # reentrega. Sem uma chave que colapse a duplicata, o primeiro dia movimentado
  # gera oportunidade em dobro.
  Result = Struct.new(:status, :contact, :kanban_card, :error, keyword_init: true) do
    def ok? = status == 'created' || status == 'duplicate'
  end

  CONTACT_KEYS = %w[name email phone_number].freeze

  def initialize(source:, payload:, locale: 'pt_BR')
    @source = source
    @payload = payload.to_h.stringify_keys
    @locale = locale
  end

  def perform
    return Result.new(status: 'rejected', error: 'contact_identity_required') if identity.blank?

    existing = existing_touchpoint
    return Result.new(status: 'duplicate', contact: existing.contact, kanban_card: existing.kanban_card) if existing

    ingest
  rescue Marketing::CreateLeadOpportunityService::DestinationError
    Result.new(status: 'rejected', error: 'destination_unavailable')
  rescue ActiveRecord::RecordInvalid => e
    Result.new(status: 'rejected', error: e.record.errors.full_messages.to_sentence)
  end

  private

  attr_reader :source, :payload, :locale

  delegate :account, to: :source

  def attribution
    @attribution ||= Marketing::AttributionFields.normalize(payload)
  end

  # Sem e-mail nem telefone nao ha a quem atribuir nada, e criar contato
  # anonimo so encheria o CRM.
  def identity
    @identity ||= contact_attributes.slice('email', 'phone_number').compact_blank
  end

  def contact_attributes
    @contact_attributes ||= payload.slice(*CONTACT_KEYS).transform_values { |v| v.to_s.strip.presence }.tap do |attrs|
      attrs['phone_number'] = normalized_phone if attrs['phone_number'].present?
    end
  end

  def normalized_phone
    Forms::PhoneNumberNormalizer.new(phone_number: payload['phone_number'], locale: locale).call
  end

  # As partes, nao o digest: quem grava o toque aplica `digest_for` nelas, e
  # procurar pelo digest ja calculado nunca casaria com o que fica guardado.
  def dedupe_parts
    @dedupe_parts ||= ['intake', source.id, payload['idempotency_key'].presence || payload.sort.to_s]
  end

  def dedupe_digest
    @dedupe_digest ||= MarketingTouchpoint.digest_for(*dedupe_parts)
  end

  def existing_touchpoint
    MarketingTouchpoint.find_by(account_id: account.id, dedupe_digest: dedupe_digest)
  end

  def ingest
    contact = find_or_create_contact
    card = Marketing::CreateLeadOpportunityService.new(
      account: account, contact: contact, destination: source.crm_destination, subject: opportunity_subject(contact)
    ).perform

    Marketing::RecordTouchpointService.new(
      account: account, source: 'form_submission', attribution: attribution,
      contact: contact, kanban_card: card, dedupe_parts: dedupe_parts
    ).perform
    Marketing::StampCardAttributionService.new(kanban_card: card).perform
    source.register_delivery!

    Result.new(status: 'created', contact: contact, kanban_card: card)
  end

  def find_or_create_contact
    existing_contact || account.contacts.create!(contact_attributes.compact_blank)
  end

  def existing_contact
    matches = [contact_by_email, contact_by_phone].compact.uniq
    # Duas pessoas diferentes com o mesmo e-mail e telefone e um dado sujo que
    # nao cabe a esta porta resolver.
    raise ActiveRecord::RecordInvalid, account.contacts.new if matches.many?

    matches.first
  end

  def contact_by_email
    return if contact_attributes['email'].blank?

    account.contacts.from_email(contact_attributes['email'])
  end

  def contact_by_phone
    return if contact_attributes['phone_number'].blank?

    account.contacts.find_by(phone_number: contact_attributes['phone_number'])
  end

  def opportunity_subject(contact)
    payload['subject'].to_s.strip.presence || "#{source.name} - #{contact.name.presence || contact.phone_number}"
  end
end
