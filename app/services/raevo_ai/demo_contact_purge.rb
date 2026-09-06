class RaevoAi::DemoContactPurge
  class UnsafePurge < StandardError; end

  def initialize(account:, contact:, expected_phone_suffix:)
    @account = account
    @contact = contact
    @expected_phone_suffix = expected_phone_suffix.to_s.gsub(/\D/, '')
  end

  def perform!
    validate_target!
    conversations = @account.conversations.where(contact: @contact).to_a
    cards = KanbanCard.where(account: @account, contact: @contact).to_a
    validate_card_dependencies!(cards)

    ActiveRecord::Base.transaction do
      cards.each { |card| delete_card!(card) }
      ConversationKanbanState.where(account: @account, conversation_id: conversations.map(&:id)).delete_all
      conversations.each { |conversation| delete_conversation!(conversation) }
      @contact.update!(name: '', email: nil, label_list: [])
    end

    {
      'contact_id' => @contact.id,
      'conversations_deleted' => conversations.length,
      'opportunities_deleted' => cards.length
    }
  end

  private

  def validate_target!
    raise UnsafePurge, 'contact does not belong to the supplied account' unless @contact.account_id == @account.id
    raise UnsafePurge, 'expected phone suffix is required' if @expected_phone_suffix.blank?

    phone_digits = @contact.phone_number.to_s.gsub(/\D/, '')
    return if phone_digits.end_with?(@expected_phone_suffix)

    raise UnsafePurge, 'contact phone suffix does not match the explicit demo target'
  end

  def validate_card_dependencies!(cards)
    card_ids = cards.map(&:id)
    return if card_ids.empty?

    protected_records = {
      'payments' => FinancePayment.exists?(account: @account, kanban_card_id: card_ids),
      'appointments' => KanbanCalendarAppointment.exists?(account: @account, kanban_card_id: card_ids),
      'appointment_series' => KanbanCalendarAppointmentSeries.exists?(account: @account, kanban_card_id: card_ids),
      'form_invitations' => FormInvitation.exists?(account: @account, kanban_card_id: card_ids),
      'form_submissions' => FormSubmission.exists?(account: @account, kanban_card_id: card_ids)
    }.select { |_name, exists| exists }.keys

    return if protected_records.empty?

    raise UnsafePurge, "demo contact has protected records: #{protected_records.join(', ')}"
  end

  def delete_card!(card)
    event_ids = card.kanban_card_events.pluck(:id)
    KanbanAutomationExecution.where(kanban_card_id: card.id).or(
      KanbanAutomationExecution.where(kanban_card_event_id: event_ids)
    ).delete_all
    KanbanAppointmentReminderDelivery.where(kanban_card_id: card.id).delete_all
    KanbanCadenceEnrollment.where(kanban_card_id: card.id).delete_all
    KanbanCardEvent.where(id: event_ids).delete_all
    card.destroy!
  end

  def delete_conversation!(conversation)
    conversation.messages.find_each(&:destroy!)
    conversation.destroy!
  end
end
