# Importa uma linha de CSV como oportunidade.
#
# Quem migra de outro CRM traz o histórico todo de uma vez, e um importador que
# engole erros em silêncio é pior do que não existir: ninguém descobre o que
# ficou por importar. Por isso cada linha ou entra inteira, ou sai com a razão
# escrita — nunca meia.
#
# A linha liga-se ao contacto que já lá está e, não o encontrando, cria-o. Isto
# reverte a decisão anterior de nunca criar: exigir a importação de contactos
# primeiro obrigava a duas migrações em ordem certa, e quem trazia oportunidade
# de outro CRM via metade das linhas recusada sem caminho óbvio.
#
# O risco de reverter é ficar com a mesma pessoa duas vezes na base, e ele mora
# todo no casamento: um telefone que chega «11999998888» não casa com o
# «+5511999998888» que está guardado, e o importador criaria a duplicata. Por
# isso o número é normalizado ANTES de procurar, não só antes de gravar.
class KanbanCards::RowImporter
  SUBJECT_KEYS = %w[assunto subject titulo title oportunidade].freeze
  EMAIL_KEYS = %w[email e-mail].freeze
  PHONE_KEYS = %w[telefone phone telemovel celular].freeze
  CONTACT_NAME_KEYS = %w[nome name contacto contato cliente paciente].freeze
  STAGE_KEYS = %w[etapa stage fase status].freeze
  AMOUNT_KEYS = %w[valor amount valor_orcado].freeze
  DEFAULT_LOCALE = 'pt_BR'.freeze

  # Os campos nativos resolvem-se pelo nome da coluna quando ele calha coincidir
  # com o nosso vocabulário. Só que um CRM antigo raramente chama «valor» ao
  # valor: chama «Valor da Proposta». Antes disto, essa coluna não tinha como
  # ser aproveitada — não havia nome que batesse nem destino no emparelhamento,
  # e o dado entrava mudo. Agora o ecrã também deixa apontar uma coluna a um
  # campo nativo, e essa escolha manda sempre à frente da lista de palavras:
  # quem mapeou à mão sabe melhor do que nós o que a coluna é.
  #
  # O prefixo leva dois pontos de propósito. A chave de um campo personalizado
  # passa por `parameterize`, que só devolve letras, dígitos e underscore — logo
  # nunca pode colidir com uma destas.
  NATIVE_SUBJECT = 'native:subject'.freeze
  NATIVE_STAGE = 'native:stage'.freeze
  NATIVE_AMOUNT = 'native:amount'.freeze
  NATIVE_EMAIL = 'native:email'.freeze
  NATIVE_PHONE = 'native:phone'.freeze
  NATIVE_CONTACT_NAME = 'native:contact_name'.freeze
  NATIVE_KEYS = [NATIVE_SUBJECT, NATIVE_STAGE, NATIVE_AMOUNT, NATIVE_EMAIL, NATIVE_PHONE, NATIVE_CONTACT_NAME].freeze

  # Sinaliza a linha ambígua de dentro da resolução do contacto até ao `import`,
  # que é onde uma linha se transforma em erro escrito em vez de rebentar.
  IdentityConflict = Class.new(StandardError)

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

    contact = resolve_contact(row)
    return Result.new(error: I18n.t('errors.kanban_import.contact_identity_required')) if contact.blank?

    subject = subject_for(row, contact)
    return Result.new(error: I18n.t('errors.kanban_import.subject_missing')) if subject.blank?

    guardar(build_card(row, contact, subject))
  rescue IdentityConflict
    Result.new(error: I18n.t('errors.kanban_import.contact_identity_conflict'))
  rescue ActiveRecord::RecordInvalid => e
    # Um telefone que não chega a E.164 nem depois de normalizado derruba só a
    # linha, com a razão escrita, em vez de abortar a migração inteira.
    Result.new(error: e.record.errors.full_messages.join(', '))
  end

  private

  attr_reader :board, :fallback_stage, :mapping

  # O contacto acabado de criar já traz nome; o que existia pode não trazer.
  def subject_for(row, contact)
    native_value(row, NATIVE_SUBJECT, SUBJECT_KEYS).presence || contact.name
  end

  def guardar(card)
    return Result.new(card: card) if card.save

    Result.new(error: card.errors.full_messages.join(', '))
  end

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
    nome = native_value(row, NATIVE_STAGE, STAGE_KEYS)
    return fallback_stage if nome.blank?

    board.kanban_stages.active.find { |stage| stage.name.casecmp?(nome.strip) } || fallback_stage
  end

  # Sem e-mail nem telefone não há a quem ligar a oportunidade, e criar um
  # contacto anónimo só encheria a base — a linha é recusada a dizer porquê.
  def resolve_contact(row)
    identidade = contact_identity(row)
    return if identidade[:email].blank? && identidade[:phone_number].blank?

    # Dentro do mesmo ficheiro, a segunda linha da mesma pessoa já encontra o
    # contacto que a primeira criou. O que escapava eram duas importações a
    # decorrer ao mesmo tempo — dois ficheiros que se sobrepõem: ambas
    # procuravam antes de qualquer uma criar, e criavam a pessoa duas vezes.
    #
    # O lock é por conta e identidade, não pela importação: duas migrações de
    # clínicas diferentes, ou da mesma clínica com pessoas diferentes, continuam
    # a correr lado a lado. Só espera quem fala da mesma pessoa.
    ActiveRecord::Base.transaction do
      bloquear_identidade(identidade)
      find_contact(identidade) || create_contact(row, identidade)
    end
  end

  # As chaves vão ordenadas de propósito. Uma linha com e-mail e telefone pega
  # em dois locks, e duas linhas a pegá-los por ordens opostas dariam impasse.
  def bloquear_identidade(identidade)
    identidade.values_at(:email, :phone_number).compact_blank.sort.each do |valor|
      ActiveRecord::Base.connection.exec_query(
        'SELECT pg_advisory_xact_lock(hashtextextended($1, 1))',
        'kanban_import_identity_lock',
        [ActiveRecord::Relation::QueryAttribute.new(
          'chave', "kanban-import:#{board.account_id}:#{valor}", ActiveRecord::Type::String.new
        )]
      )
    end
  end

  def contact_identity(row)
    telefone = native_value(row, NATIVE_PHONE, PHONE_KEYS)
    {
      email: native_value(row, NATIVE_EMAIL, EMAIL_KEYS).presence,
      phone_number: normalized_phone(telefone)
    }
  end

  def normalized_phone(telefone)
    return if telefone.blank?

    Forms::PhoneNumberNormalizer.new(phone_number: telefone, locale: locale).call
  end

  def locale
    board.account.locale.presence || DEFAULT_LOCALE
  end

  # O e-mail e o telefone da mesma linha podem apontar a pessoas diferentes: um
  # ficheiro antigo traz o e-mail de quem marcou e o telemóvel de quem foi
  # atendido. Devolver o primeiro que aparecesse ligava a oportunidade a meio
  # palpite, em silêncio, e ninguém tinha como notar. A linha é recusada para
  # alguém olhar — o mesmo que o formulário público já faz.
  def find_contact(identidade)
    correspondencias = [contact_by_email(identidade), contact_by_phone(identidade)].compact.uniq
    raise IdentityConflict if correspondencias.many?

    correspondencias.first
  end

  def contact_by_email(identidade)
    return if identidade[:email].blank?

    board.account.contacts.from_email(identidade[:email])
  end

  def contact_by_phone(identidade)
    return if identidade[:phone_number].blank?

    board.account.contacts.find_by(phone_number: identidade[:phone_number])
  end

  def create_contact(row, identidade)
    board.account.contacts.create!(
      name: native_value(row, NATIVE_CONTACT_NAME, CONTACT_NAME_KEYS).presence || identidade[:email] || identidade[:phone_number],
      **identidade.compact
    )
  end

  # Vírgula decimal é o normal em pt: «1.250,50» tem de chegar como 125050.
  def amount_cents_for(row)
    bruto = native_value(row, NATIVE_AMOUNT, AMOUNT_KEYS)
    return nil if bruto.blank?

    normalizado = bruto.to_s.gsub(/[^\d,.-]/, '').tr('.', '').tr(',', '.')
    numero = Float(normalizado, exception: false)
    numero.nil? ? nil : (numero * 100).round
  end

  # Uma coluna apontada a campo nativo não é campo personalizado: se entrasse
  # aqui também, o valor ficava nos dois sítios e a ficha passava a mostrar
  # «Etapa» duas vezes, uma delas por baixo dos campos do cliente.
  def custom_values_for(row)
    mapping.each_with_object({}) do |(coluna, chave), valores|
      next if chave.blank? || NATIVE_KEYS.include?(chave.to_s)

      valor = row[coluna.to_s]
      valores[chave.to_s] = valor if valor.present?
    end
  end

  # Primeiro o que o ecrã mapeou, depois o nome da coluna. Nunca ao contrário.
  def native_value(row, native_key, fallback_keys)
    mapped_value(row, native_key).presence || value_for(row, fallback_keys)
  end

  def mapped_value(row, native_key)
    coluna = mapping.find { |_coluna, chave| chave.to_s == native_key }&.first
    return if coluna.blank?

    row[coluna.to_s].to_s.strip
  end

  def value_for(row, keys)
    chave = row.keys.compact.find { |k| keys.include?(k.to_s.strip.downcase) }
    chave.nil? ? nil : row[chave].to_s.strip
  end
end
