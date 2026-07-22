class KanbanBoards::ScheduleAppointmentRemindersService
  REMINDER_TYPE = 'Lembrete de agendamento'.freeze

  def initialize(board, now: Time.current)
    @board = board
    @now = now
  end

  def call
    return 0 if @board.appointment_reminder_hours.blank?

    scheduled_count = 0
    reminder_scope.find_each do |card|
      next_action_at = [card.starts_at - @board.appointment_reminder_hours.hours, @now].max

      card.with_lock do
        next if card.next_action_at.present? || card.won_at.present? || card.lost_at.present?

        card.update!(
          next_action_type: REMINDER_TYPE,
          next_action_at: next_action_at,
          next_action_note: "Agendamento em #{card.starts_at.in_time_zone.strftime('%d/%m/%Y %H:%M')}"
        )
        scheduled_count += 1
      end
    end

    scheduled_count
  end

  private

  def reminder_scope
    @board.kanban_cards.active
          .where(won_at: nil, lost_at: nil, next_action_at: nil)
          .where('starts_at > ?', @now)
          .where.not(starts_at: nil)
  end
end
