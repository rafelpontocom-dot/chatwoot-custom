# Raevo — o que nunca deve virar oportunidade.
#
# O feed de status do WhatsApp (`status@broadcast`) chega como uma conversa
# normal: um contato chamado "Status" que junta as publicações de todo mundo que
# a clínica tem na agenda. Em produção ele virou contato, conversa e **card no
# funil**, atribuído a uma médica e sem próxima ação — uma oportunidade que nunca
# fecha, ocupando espaço numa etapa.
#
# Grupo (`@g.us`) já era filtrado na importação, mas só quando `ignore_groups`
# estava ligado, e a criação automática não filtrava nada. Este módulo é o único
# lugar que define "isto não é uma pessoa", e serve os dois caminhos: a
# importação em massa, que trabalha em SQL, e a criação automática, que trabalha
# com um objeto.
module KanbanCards::ConversationEligibility
  # Broadcast nunca é uma pessoa: vale para importação e para criação automática,
  # sem depender de configuração.
  BROADCAST_PATTERN = '%@broadcast%'.freeze
  # Grupo é uma decisão do funil — pode haver quem queira acompanhar um grupo —
  # por isso continua atrás de `ignore_groups` na importação.
  GROUP_PATTERN = '%@g.us%'.freeze

  # Campos onde o endereço de origem pode aparecer, em ordem de confiabilidade.
  IDENTIFIER_COLUMNS = [
    'conversations.identifier',
    'contacts.identifier',
    'contacts.phone_number',
    'contact_inboxes.source_id'
  ].freeze

  module_function

  # Remove de uma relação de conversas tudo que casar com os padrões dados.
  def exclude_identifiers(relation, patterns)
    relation = relation.left_joins(:contact, :contact_inbox)

    patterns.each do |pattern|
      IDENTIFIER_COLUMNS.each do |column|
        relation = relation.where.not("LOWER(COALESCE(#{column}, ?)) LIKE ?", '', pattern)
      end
    end

    relation
  end

  # Vale para uma conversa já carregada — o caminho da criação automática.
  def broadcast?(conversation)
    identifiers_for(conversation).any? { |value| value.include?('@broadcast') }
  end

  def group?(conversation)
    identifiers_for(conversation).any? { |value| value.include?('@g.us') }
  end

  def identifiers_for(conversation)
    contact = conversation.contact
    contact_inbox = conversation.contact_inbox

    [
      conversation.identifier,
      contact&.identifier,
      contact&.phone_number,
      contact_inbox&.source_id
    ].compact_blank.map(&:downcase)
  end
end
