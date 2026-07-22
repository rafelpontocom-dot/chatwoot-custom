class KanbanBoards::DuplicateService
  BOARD_CONFIGURATION_ATTRIBUTES = %w[
    description
    auto_create_cards_from_conversations
    compact_card_field_keys
    custom_field_definitions
    custom_field_sections
    inbox_scope_mode
    lost_reason_options
    next_action_types
    stale_stage_thresholds
    use_opportunity_card_reads
    visibility_mode
  ].freeze

  def initialize(board:)
    @board = board
  end

  def perform!
    KanbanBoard.transaction do
      duplicate = create_board
      stage_id_map = duplicate_stages(duplicate)
      duplicate.update!(stale_stage_thresholds: remapped_stale_thresholds(stage_id_map))
      duplicate_access_configuration(duplicate)
      duplicate
    end
  end

  private

  attr_reader :board

  def create_board
    KanbanBoard.create!(board_configuration.merge(account: board.account, name: duplicate_name, position: next_position))
  end

  def board_configuration
    board.attributes.slice(*BOARD_CONFIGURATION_ATTRIBUTES).deep_dup
  end

  def duplicate_name
    base_name = "#{board.name} (copy)"
    return base_name unless KanbanBoard.active.exists?(account_id: board.account_id, name: base_name)

    suffix = 2
    loop do
      candidate = "#{base_name} #{suffix}"
      return candidate unless KanbanBoard.active.exists?(account_id: board.account_id, name: candidate)

      suffix += 1
    end
  end

  def next_position
    KanbanBoard.where(account_id: board.account_id).maximum(:position).to_i + 1
  end

  def duplicate_stages(duplicate)
    board.kanban_stages.active.ordered.each_with_object({}) do |stage, stage_id_map|
      copied_stage = duplicate.kanban_stages.create!(
        account: board.account,
        name: stage.name,
        position: stage.position,
        color: stage.color,
        category: stage.category,
        wip_limit: stage.wip_limit,
        probability: stage.probability
      )
      stage_id_map[stage.id.to_s] = copied_stage.id.to_s
    end
  end

  def remapped_stale_thresholds(stage_id_map)
    board.stale_stage_thresholds.to_h.each_with_object({}) do |(stage_id, threshold), thresholds|
      copied_stage_id = stage_id_map[stage_id.to_s]
      thresholds[copied_stage_id] = threshold if copied_stage_id.present?
    end
  end

  def duplicate_access_configuration(duplicate)
    board.kanban_board_members.find_each do |member|
      duplicate.kanban_board_members.create!(account: board.account, user_id: member.user_id)
    end
    board.kanban_board_inboxes.find_each do |board_inbox|
      duplicate.kanban_board_inboxes.create!(account: board.account, inbox_id: board_inbox.inbox_id)
    end
  end
end
