class KanbanCardListener < BaseListener
  KANBAN_EVENT_NAMES = KanbanAutomationRule::EVENT_NAMES.freeze

  def conversation_created(event)
    conversation = event.data[:conversation]
    return if conversation.blank?

    KanbanCards::AutoCreateFromConversationJob.perform_later(conversation.id)
  end

  def message_created(event)
    message = event.data[:message]
    return unless message&.incoming?

    KanbanCard.where(account_id: message.account_id, conversation_id: message.conversation_id, active: true).find_each do |card|
      KanbanCadences::PauseService.call_for_card(
        card,
        reason: 'Paused after an incoming customer message',
        only_if_pause_on_incoming: true
      )
    end
  end

  KANBAN_EVENT_NAMES.each do |event_name|
    define_method(event_name.tr('.', '_')) do |event|
      process_kanban_event(event)
    end
  end

  private

  def process_kanban_event(event)
    data = event.data.with_indifferent_access
    process_cadence_event(data)
    return if data[:account_id].blank? || data[:board_id].blank? || data[:card_id].blank?

    event_key = data[:event_id].presence || "#{event.name}:#{data[:card_id]}"
    KanbanAutomationRule.active
                        .where(account_id: data[:account_id], kanban_board_id: data[:board_id], event_name: event.name)
                        .find_each do |rule|
      KanbanAutomations::ExecuteRuleJob.perform_later(
        rule.id,
        event.name,
        event_key,
        data[:card_id],
        data[:event_id]
      )
    end
  end

  def process_cadence_event(data)
    card = KanbanCard.find_by(id: data[:card_id], account_id: data[:account_id])
    return if card.blank?

    if data[:event_type].to_s == 'stage_changed'
      KanbanCadences::EnrollOnStageEntryService.new(card: card, stage: card.kanban_stage).call
      KanbanAppointmentReminderRule.active.where(kanban_board_id: card.kanban_board_id,
                                                 trigger_type: 'stage_entered',
                                                 trigger_stage_id: card.kanban_stage_id).find_each do |rule|
        KanbanAppointmentReminders::ScheduleService.new(card: card, rule: rule).call
      end
    end

    case data[:event_type].to_s
    when 'next_action_completed'
      KanbanCadences::CompleteStepService.call_for_card(card)
    when 'card_won', 'card_lost', 'card_archived'
      KanbanCadences::PauseService.call_for_card(card, reason: "Paused after #{data[:event_type]}")
    end
  end
end
