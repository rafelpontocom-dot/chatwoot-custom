class KanbanCadences::PauseService
  def self.call_for_card(card, reason: nil, only_if_pause_on_incoming: false)
    enrollments = card.kanban_cadence_enrollments.where(status: %w[active awaiting_completion])
    if only_if_pause_on_incoming
      enrollments = enrollments.joins(:kanban_cadence).where(
        kanban_cadences: { pause_on_incoming_message: true }
      )
    end

    enrollments.find_each do |enrollment|
      enrollment.update!(status: 'paused', paused_at: Time.current, next_run_at: nil, last_error: reason)
    end
  end
end
