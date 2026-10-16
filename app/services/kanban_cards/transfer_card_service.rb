class KanbanCards::TransferCardService
  attr_reader :source_stage

  # rubocop:disable Metrics/ParameterLists -- Mirrors the transfer request contract.
  def initialize(card:, target_board:, target_stage:, actor:, lost_reason: nil, custom_field_values: {})
    @card = card
    @source_board = card.kanban_board
    @source_stage = card.kanban_stage
    @target_board = target_board
    @target_stage = target_stage
    @actor = actor
    @lost_reason = lost_reason.to_s.strip.presence
    # Os campos que a etapa de destino exige e o cartão ainda não tem. Só os do
    # funil de destino: o resto da ficha muda-se em PATCH, não numa mudança de funil.
    target_keys = target_board.custom_field_definitions.pluck('key')
    @custom_field_values = custom_field_values.to_h.stringify_keys.slice(*target_keys)
  end
  # rubocop:enable Metrics/ParameterLists

  def perform!
    validate_target!

    KanbanCard.transaction do
      lock_transfer_records!
      normalize_positions!
      transfer_card!
      fill_required_fields!
      normalize_positions!
      create_transfer_event!
    end

    @card.reload
  end

  private

  def validate_target!
    validate_target_stage!
    validate_lost_reason!
    validate_required_fields!
  ensure
    @card.reload if @card.persisted? && @card.errors.blank?
  end

  def validate_target_stage!
    raise ActiveRecord::RecordInvalid, @card unless @target_stage.kanban_board_id == @target_board.id
  end

  def validate_lost_reason!
    return unless @target_stage.category == 'lost' && @lost_reason.blank?

    @card.errors.add(:lost_reason, :blank)
    raise ActiveRecord::RecordInvalid, @card
  end

  def validate_required_fields!
    @card.kanban_board = @target_board
    @card.kanban_stage = @target_stage
    @card.custom_field_values = merged_custom_field_values
    missing_field_keys = @card.missing_required_custom_field_keys
    return if missing_field_keys.blank?

    missing_field_keys.each { |field_key| @card.errors.add(:custom_field_values, "#{field_key} is required") }
    raise ActiveRecord::RecordInvalid, @card
  end

  # Grava com validações: o valor de um campo de escolha tem de ser uma das
  # opções, e é o modelo que o sabe. Mas o modelo só guarda os campos do funil
  # em que o cartão está, e gravar apagava os do funil de origem («Fonte da
  # lista», visto em produção a 16/10). Uma mudança sem campos em falta não os
  # toca; com campos em falta também não pode, e por isso voltam a juntar-se.
  def fill_required_fields!
    return if @custom_field_values.blank?

    source_values = @card.custom_field_values.to_h
    @card.update!(custom_field_values: merged_custom_field_values)
    @card.update_column(:custom_field_values, source_values.merge(@card.custom_field_values)) # rubocop:disable Rails/SkipsModelValidations
  end

  def merged_custom_field_values
    @card.custom_field_values.to_h.merge(@custom_field_values)
  end

  def lock_transfer_records!
    KanbanCard.lock_reorder_stages!([source_stage.id, @target_stage.id])
    KanbanCard.lock_active_cards_for_stages!(@source_board, [source_stage.id])
    KanbanCard.lock_active_cards_for_stages!(@target_board, [@target_stage.id])
  end

  def normalize_positions!
    KanbanCard.normalize_positions_for_stage!(kanban_board: @source_board, kanban_stage: source_stage)
    KanbanCard.normalize_positions_for_stage!(kanban_board: @target_board, kanban_stage: @target_stage)
  end

  def transfer_card!
    @transferred_at = Time.current
    destination_position = @target_board.kanban_cards.active.where(kanban_stage: @target_stage).maximum(:position).to_i + 1

    # The transfer is recorded by the explicit immutable event below.
    @card.update_columns( # rubocop:disable Rails/SkipsModelValidations
      kanban_board_id: @target_board.id,
      kanban_stage_id: @target_stage.id,
      position: destination_position,
      stage_entered_at: @transferred_at,
      won_at: won_at,
      lost_at: lost_at,
      lost_reason: @target_stage.category == 'lost' ? @lost_reason : nil,
      closed_by_id: closed_by_id,
      lock_version: @card.lock_version + 1,
      updated_at: @transferred_at
    )
    @card.reload
  end

  def create_transfer_event!
    @card.kanban_card_events.create!(
      account: @card.account,
      kanban_board: @target_board,
      event_type: 'stage_changed',
      actor: @actor,
      occurred_at: @transferred_at,
      change_set: {
        'kanban_board_id' => [@source_board.id, @target_board.id],
        'kanban_stage_id' => [source_stage.id, @target_stage.id]
      },
      metadata: {
        'from_board' => board_snapshot(@source_board),
        'to_board' => board_snapshot(@target_board),
        'from_stage' => stage_snapshot(source_stage),
        'to_stage' => stage_snapshot(@target_stage),
        'entered_at' => @transferred_at.iso8601
      }
    )
  end

  def won_at
    @target_stage.category == 'won' ? @transferred_at : nil
  end

  def lost_at
    @target_stage.category == 'lost' ? @transferred_at : nil
  end

  def closed_by_id
    @target_stage.category.in?(%w[won lost]) ? @actor.id : nil
  end

  def board_snapshot(board)
    { 'id' => board.id, 'name' => board.name }
  end

  def stage_snapshot(stage)
    { 'id' => stage.id, 'name' => stage.name, 'category' => stage.category }
  end
end
