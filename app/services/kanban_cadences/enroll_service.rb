class KanbanCadences::EnrollService
  def initialize(card:, cadence:, user:)
    @card = card
    @cadence = cadence
    @user = user
  end

  def call
    validate_scope!
    step = cadence.steps.first.to_h.with_indifferent_access
    existing = KanbanCadenceEnrollment.find_by(kanban_card: card, kanban_cadence: cadence)
    return restart!(existing, step) if existing.present?

    KanbanCadenceEnrollment.create!(enrollment_attributes(step))
  end

  private

  attr_reader :card, :cadence, :user

  def enrollment_attributes(step)
    {
      account: card.account,
      kanban_board: card.kanban_board,
      kanban_card: card,
      kanban_cadence: cadence,
      owner: card.owner || user,
      current_step: 0,
      status: 'active',
      next_run_at: Time.current + step[:delay_hours].to_f.hours,
      started_at: Time.current
    }
  end

  def restart!(enrollment, step)
    if enrollment.active? || enrollment.awaiting_completion?
      card.errors.add(:base, 'This opportunity is already enrolled in this cadence')
      raise ActiveRecord::RecordInvalid, card
    end

    enrollment.update!(
      enrollment_attributes(step).except(:account, :kanban_board, :kanban_card, :kanban_cadence).merge(
        paused_at: nil,
        completed_at: nil,
        last_run_at: nil,
        last_error: nil
      )
    )
    enrollment
  end

  def validate_scope!
    invalid_scope! unless same_board?
    invalid_scope! unless same_account?
    invalid_scope! unless card.active? && cadence.active?
    reject_active_enrollment!
  end

  def same_board?
    card.kanban_board_id == cadence.kanban_board_id
  end

  def same_account?
    card.account_id == cadence.account_id
  end

  def reject_active_enrollment!
    existing = KanbanCadenceEnrollment.find_by(kanban_card: card, kanban_cadence: cadence)
    return unless existing&.active? || existing&.awaiting_completion?

    card.errors.add(:base, 'This opportunity is already enrolled in this cadence')
    raise ActiveRecord::RecordInvalid, card
  end

  def invalid_scope!
    raise ActiveRecord::RecordInvalid, card
  end
end
