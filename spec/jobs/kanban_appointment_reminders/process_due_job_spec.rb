require 'rails_helper'

RSpec.describe KanbanAppointmentReminders::ProcessDueJob do
  it 'processes due deliveries in bounded batches' do
    relation = instance_double(ActiveRecord::Relation)

    allow(KanbanAppointmentReminderDelivery).to receive(:due).and_return(relation)
    allow(relation).to receive(:includes)
      .with(:kanban_appointment_reminder_rule, :kanban_card)
      .and_return(relation)
    expect(relation).to receive(:find_each).with(batch_size: described_class::BATCH_SIZE)

    described_class.perform_now
  end
end
