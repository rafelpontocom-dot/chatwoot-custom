require 'rails_helper'

RSpec.describe KanbanBirthdayAutomations::ProcessJob, type: :job do
  it 'processes only active birthday automations' do
    active = create(:kanban_birthday_automation, active: true)
    inactive = create(:kanban_birthday_automation, active: false)

    expect(KanbanBirthdayAutomations::ProcessService).to receive(:new).with(automation: active).and_call_original
    expect(KanbanBirthdayAutomations::ProcessService).not_to receive(:new).with(automation: inactive)

    described_class.perform_now
  end
end
