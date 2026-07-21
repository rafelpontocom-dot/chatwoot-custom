class KanbanCards::BulkUpdateService
  MAX_CARDS = 100
  OPERATIONS = %w[archive assign_owner move_stage].freeze

  def initialize(board:, cards:, user:, operation:, options: {})
    @board = board
    @cards = cards
    @user = user
    @operation = operation
    @owner_id = options[:owner_id]
    @stage_id = options[:stage_id]
    @lost_reason = options[:lost_reason]
  end

  def perform!
    validate_request!

    KanbanCard.transaction do
      cards.each { |card| apply_operation!(card) }
    end

    cards.length
  end

  private

  attr_reader :board, :cards, :user, :operation, :owner_id, :stage_id, :lost_reason

  def validate_request!
    add_board_error!('Select at least one opportunity') if cards.blank?
    add_board_error!("Select no more than #{MAX_CARDS} opportunities") if cards.length > MAX_CARDS
    add_board_error!('Operation is invalid') unless OPERATIONS.include?(operation)
    owner if operation == 'assign_owner'
    target_stage if operation == 'move_stage'
  end

  def apply_operation!(card)
    case operation
    when 'archive' then card.archive!(actor: user)
    when 'assign_owner' then card.update!(owner: owner)
    when 'move_stage' then move_card!(card)
    end
  end

  def move_card!(card)
    card.reorder_to_position!(kanban_stage: target_stage, position: next_position)
    card.update!(stage_category_attributes)
  end

  def next_position
    board.kanban_cards.active.where(kanban_stage: target_stage).maximum(:position).to_i + 1
  end

  def stage_category_attributes
    case target_stage.category
    when 'won'
      { won_at: Time.current, lost_at: nil, lost_reason: nil, closed_by: user }
    when 'lost'
      add_board_error!('Lost reason is required') if lost_reason.blank?
      { won_at: nil, lost_at: Time.current, lost_reason: lost_reason, closed_by: user }
    else
      { won_at: nil, lost_at: nil, lost_reason: nil, closed_by: nil }
    end
  end

  def owner
    @owner ||= board.account.users.find(owner_id)
  end

  def target_stage
    @target_stage ||= board.kanban_stages.active.find(stage_id)
  end

  def add_board_error!(message)
    board.errors.add(:base, message)
    raise ActiveRecord::RecordInvalid, board
  end
end
