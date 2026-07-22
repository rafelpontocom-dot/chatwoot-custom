class KanbanCadences::AdvanceService
  def initialize(enrollment)
    @enrollment = enrollment
  end

  def call
    enrollment.with_lock do
      if enrollment.active? && card_closed?
        pause!
      elsif enrollment.active? && due?
        apply_due_step!
      end
    end

    enrollment
  rescue StandardError => e
    enrollment.update_columns(last_error: e.message, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    raise
  end

  private

  attr_reader :enrollment

  delegate :kanban_card, :kanban_cadence, to: :enrollment
  alias card kanban_card
  alias cadence kanban_cadence

  def due?
    enrollment.next_run_at.present? && enrollment.next_run_at <= Time.current
  end

  def card_closed?
    !card.active? || card.won_at.present? || card.lost_at.present?
  end

  def apply_due_step!
    step = cadence.steps[enrollment.current_step].to_h.with_indifferent_access
    card.update!(
      next_action_type: step[:action_type],
      next_action_at: Time.current,
      next_action_note: step[:note].presence,
      next_action_completed_at: nil
    )
    enrollment.update!(status: 'awaiting_completion', next_run_at: nil, last_run_at: Time.current, last_error: nil)
  end

  def pause!
    enrollment.update!(status: 'paused', paused_at: Time.current, next_run_at: nil)
    enrollment
  end
end
