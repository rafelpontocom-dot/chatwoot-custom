class KanbanCadences::EnrollOnStageEntryService
  def initialize(card:, stage:)
    @card = card
    @stage = stage
  end

  def call
    enrollments = cadences.filter_map { |cadence| enroll(cadence) }
    return if enrollments.empty?

    enrollments.one? ? enrollments.first : enrollments
  end

  private

  attr_reader :card, :stage

  def cadences
    card.kanban_board.kanban_cadences.active.where(
      trigger_type: 'stage_entered', trigger_stage_id: stage.id
    )
  end

  def enroll(cadence)
    existing = card.kanban_cadence_enrollments.find_by(kanban_cadence: cadence)
    return existing if existing&.active? || existing&.awaiting_completion?

    KanbanCadences::EnrollService.new(
      card: card,
      cadence: cadence,
      user: card.owner || card.account.users.first
    ).call
  rescue ActiveRecord::RecordNotUnique
    card.kanban_cadence_enrollments.find_by!(kanban_cadence: cadence)
  end
end
