class KanbanCadences::CompleteStepService
  def self.call_for_card(card)
    card.kanban_cadence_enrollments.awaiting_completion.find_each do |enrollment|
      new(enrollment).call
    end
  end

  def initialize(enrollment)
    @enrollment = enrollment
  end

  def call
    enrollment.with_lock do
      advance_if_waiting
    end

    enrollment
  end

  private

  attr_reader :enrollment

  delegate :kanban_cadence, to: :enrollment
  alias cadence kanban_cadence

  def advance_if_waiting
    return unless enrollment.awaiting_completion?

    next_step = enrollment.current_step + 1
    step = cadence.steps[next_step]
    return complete_cadence if step.blank?

    attributes = step.to_h.with_indifferent_access
    enrollment.update!(
      current_step: next_step,
      status: 'active',
      next_run_at: Time.current + attributes[:delay_hours].to_f.hours,
      last_run_at: Time.current
    )
  end

  def complete_cadence
    enrollment.update!(status: 'completed', completed_at: Time.current, last_run_at: Time.current)
  end
end
