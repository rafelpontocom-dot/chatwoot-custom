# Importa uma linha de CSV como oportunidade.
#
# Quem migra de outro CRM traz o histórico todo de uma vez, e um importador que
# engole erros em silêncio é pior do que não existir: ninguém descobre o que
# ficou por importar. Por isso cada linha ou entra inteira, ou sai com a razão
# escrita — nunca meia.
#
# Contactos não se criam aqui. O Chatwoot já tem importação de contactos, e
# duplicá-la seria arranjar maneira de ficar com a mesma pessoa duas vezes na
# base. A linha liga-se a quem já lá está; não encontrando, é rejeitada a dizer
# o que fazer.
class KanbanCards::RowImporter
  SUBJECT_KEYS = %w[assunto subject titulo title oportunidade].freeze
  CONTACT_KEYS = %w[email e-mail telefone phone telemovel celular].freeze
  STAGE_KEYS = %w[etapa stage fase status].freeze
  AMOUNT_KEYS = %w[valor amount valor_orcado].freeze

  Result = Struct.new(:card, :error, keyword_init: true) do
    def ok?
      error.blank?
    end
  end

  def initialize(board:, fallback_stage:, mapping: {})
    @board = board
    @fallback_stage = fallback_stage
    @mapping = mapping.presence || {}
  end

  def import(row)
    return Result.new(error: I18n.t('errors.kanban_import.inbox_missing')) if inbox.blank?

    contact = find_contact(row)
    return Result.new(error: I18n.t('errors.kanban_import.contact_not_found')) if contact.blank?

    subject = value_for(row, SUBJECT_KEYS).presence || contact.name
    return Result.new(error: I18n.t('errors.kanban_import.subject_missing')) if subject.blank?

    card = build_card(row, contact, subject)
    return Result.new(card: card) if card.save

    Result.new(error: card.errors.full_messages.join(', '))
  end

  private

  attr_reader :board, :fallback_stage, :mapping

  # O cartão exige caixa de entrada. Usa-se a do funil, se ele restringe; senão
  # a da conta. Sem nenhuma, a linha é rejeitada em vez de rebentar a meio.
  def inbox
    @inbox ||= board.allowed_inboxes.first || board.account.inboxes.first
  end

  def build_card(row, contact, subject)
    board.kanban_cards.new(
      account: board.account,
      contact: contact,
      kanban_stage: stage_for(row),
      subject: subject,
      amount_cents: amount_cents_for(row),
      custom_field_values: custom_values_for(row),
      inbox: inbox,
      # Não há origem «importado»: o enum só conhece conversa e manual, e
      # alargá-lo tocava em todo o lado que decide por origem. Um cartão
      # importado é, para todos os efeitos, um que alguém pôs lá à mão.
      origin: 'manual'
    )
  end

  # Uma etapa que não corresponde a nada não custa a linha: cai na de recurso.
  # Um nome trocado na migração não deve perder o cartão.
  def stage_for(row)
    nome = value_for(row, STAGE_KEYS)
    return fallback_stage if nome.blank?

    board.kanban_stages.active.find { |stage| stage.name.casecmp?(nome.strip) } || fallback_stage
  end

  def find_contact(row)
    contactos = board.account.contacts
    email = value_for(row, %w[email e-mail])
    telefone = value_for(row, %w[telefone phone telemovel celular])

    return contactos.from_email(email) if email.present? && contactos.from_email(email).present?

    contactos.find_by(phone_number: telefone) if telefone.present?
  end

  # Vírgula decimal é o normal em pt: «1.250,50» tem de chegar como 125050.
  def amount_cents_for(row)
    bruto = value_for(row, AMOUNT_KEYS)
    return nil if bruto.blank?

    normalizado = bruto.to_s.gsub(/[^\d,.-]/, '').tr('.', '').tr(',', '.')
    numero = Float(normalizado, exception: false)
    numero.nil? ? nil : (numero * 100).round
  end

  def custom_values_for(row)
    mapping.each_with_object({}) do |(coluna, chave), valores|
      next if chave.blank?

      valor = row[coluna.to_s]
      valores[chave.to_s] = valor if valor.present?
    end
  end

  def value_for(row, keys)
    chave = row.keys.compact.find { |k| keys.include?(k.to_s.strip.downcase) }
    chave.nil? ? nil : row[chave].to_s.strip
  end
end
