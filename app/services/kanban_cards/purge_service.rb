# Apaga de vez oportunidades excluídas. Vai-se o card e o histórico dele; o que
# tem vida própria fica e só perde a ligação: uma cobrança continua a ser a fonte
# de verdade do dinheiro, uma consulta continua na Agenda, uma resposta de
# formulário continua a ser do paciente.
class KanbanCards::PurgeService
  DETACHED = [FinancePayment, FormInvitation, FormSubmission, KanbanCalendarAppointment, KanbanCalendarAppointmentSeries].freeze

  def initialize(card_ids)
    @card_ids = card_ids
  end

  def perform
    KanbanCard.transaction do
      detach_records_that_outlive_the_card
      delete_card_history
      KanbanCard.where(id: card_ids).delete_all
    end
  end

  private

  attr_reader :card_ids

  # Só se desfaz a ligação: não há validação de negócio a correr em quem fica.
  # rubocop:disable Rails/SkipsModelValidations
  def detach_records_that_outlive_the_card
    DETACHED.each { |model| model.where(kanban_card_id: card_ids).update_all(kanban_card_id: nil) }
    KanbanAutomationExecution.where(kanban_card_id: card_ids).update_all(kanban_card_id: nil)
    KanbanAutomationExecution.where(kanban_card_event_id: events.select(:id)).update_all(kanban_card_event_id: nil)
  end
  # rubocop:enable Rails/SkipsModelValidations

  def delete_card_history
    KanbanAppointmentReminderDelivery.where(kanban_card_id: card_ids).delete_all
    KanbanCadenceEnrollment.where(kanban_card_id: card_ids).delete_all
    events.delete_all
    ActsAsTaggableOn::Tagging.where(taggable_type: KanbanCard.name, taggable_id: card_ids).delete_all
  end

  def events
    KanbanCardEvent.where(kanban_card_id: card_ids)
  end
end
