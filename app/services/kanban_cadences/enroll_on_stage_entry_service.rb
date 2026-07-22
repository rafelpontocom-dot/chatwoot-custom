class KanbanCadences::EnrollOnStageEntryService
  def initialize(card:, stage:)
    @card = card
    @stage = stage
  end

  def call
    cadence = card.kanban_board.kanban_cadences.active.find_by(
      trigger_type: 'stage_entered', trigger_stage_id: stage.id
    )
    return unless cadence

    existing = card.kanban_cadence_enrollments.find_by(kanban_cadence: cadence)
    return existing if existing&.active? || existing&.awaiting_completion?

    KanbanCadences::EnrollService.new(
      card: card,
      cadence: cadence,
      user: card.owner || card.account.users.first
    ).call
  end

  private

  attr_reader :card, :stage
end
