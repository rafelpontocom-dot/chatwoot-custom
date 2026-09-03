class Marketing::CreateLeadOpportunityService
  # Cria a oportunidade de um lead que chegou sem agente nenhum por perto.
  #
  # O `KanbanCards::CreateManualCardService` nao serve aqui: ele autoriza contra
  # um usuario, e numa entrada servidor-a-servidor nao ha usuario. O caminho
  # publico do Forms resolveu o mesmo problema, mas amarrado a uma submissao.
  # Quando o Meta Lead Ads chegar e for o terceiro consumidor, vale extrair um
  # so; com dois, uma abstracao prematura custaria mais do que a repeticao.
  OPPORTUNITY_POLICIES = %w[create_new reuse_open].freeze
  DestinationError = Class.new(StandardError)

  def initialize(account:, contact:, destination:, subject:)
    @account = account
    @contact = contact
    @destination = destination.to_h.stringify_keys
    @subject = subject
  end

  def perform
    card = KanbanCard.transaction do
      validate_destination!
      matching_card || create_card!
    end
    dispatch_card_created_event if @created_card
    card
  end

  private

  attr_reader :account, :contact, :destination, :subject

  def board
    @board ||= KanbanBoard.active.find_by(account_id: account.id, id: destination['kanban_board_id'])
  end

  def stage
    @stage ||= board&.kanban_stages&.active&.find_by(id: destination['kanban_stage_id'])
  end

  def inbox
    @inbox ||= account.inboxes.find_by(id: destination['inbox_id'])
  end

  def opportunity_policy
    destination.fetch('opportunity_policy', 'reuse_open')
  end

  def validate_destination!
    raise DestinationError if board.blank? || stage.blank? || inbox.blank?
    raise DestinationError unless stage.kanban_board_id == board.id && board.inbox_allowed?(inbox)
    raise DestinationError unless OPPORTUNITY_POLICIES.include?(opportunity_policy)
  end

  # Reaproveitar a oportunidade aberta e o padrao: a mesma pessoa preenchendo o
  # formulario duas vezes na semana e um lead, nao dois.
  def matching_card
    return if opportunity_policy == 'create_new'

    KanbanCard.open_opportunities
              .where(account: account, contact: contact, kanban_board: board)
              .order(created_at: :desc, id: :desc)
              .first
  end

  def create_card!
    stage.lock!
    KanbanCard.lock_active_cards_for_stages!(board, [stage.id])
    KanbanCard.where(kanban_board: board, kanban_stage: stage).active.update_all( # rubocop:disable Rails/SkipsModelValidations
      ['position = position + 1, updated_at = ?', Time.current]
    )
    @created_card = KanbanCard.create!(
      account: account, kanban_board: board, kanban_stage: stage,
      contact: contact, inbox: inbox, subject: subject,
      origin: 'manual', position: 1, active: true
    )
  end

  def dispatch_card_created_event
    Rails.configuration.dispatcher.dispatch(
      Events::Types::KANBAN_CARD_CREATED,
      Time.zone.now,
      account_id: @created_card.account_id,
      board_id: @created_card.kanban_board_id,
      stage_id: @created_card.kanban_stage_id,
      card_id: @created_card.id,
      conversation_id: nil
    )
  end
end
