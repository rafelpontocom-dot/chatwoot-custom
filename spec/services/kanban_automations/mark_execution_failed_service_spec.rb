require 'rails_helper'

RSpec.describe KanbanAutomations::MarkExecutionFailedService do
  it 'marks an unfinished execution as failed after retries are exhausted' do
    execution = create(:kanban_automation_execution, status: 'waiting')

    described_class.new(execution_id: execution.id, error: StandardError.new('temporary database timeout')).perform!

    expect(execution.reload).to have_attributes(
      status: 'failed',
      error_message: 'temporary database timeout',
      completed_at: be_present
    )
  end

  it 'does not overwrite an execution that already completed' do
    execution = create(:kanban_automation_execution, status: 'succeeded', completed_at: 1.minute.ago)

    described_class.new(execution_id: execution.id, error: StandardError.new('late retry')).perform!

    expect(execution.reload).to have_attributes(status: 'succeeded', error_message: nil)
  end
end
