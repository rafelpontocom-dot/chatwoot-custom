require 'rails_helper'

RSpec.describe KanbanCalendarProcedure do
  it 'accepts a procedure with duration and recurrence limits' do
    procedure = described_class.new(
      account: create(:account),
      name: 'Sessão de fisioterapia',
      duration_minutes: 50,
      buffer_before_minutes: 10,
      buffer_after_minutes: 10,
      recurrence_allowed: true,
      max_sessions: 10,
      active: true
    )

    expect(procedure).to be_valid
  end

  it 'requires a positive duration and a recurrence limit when recurrence is enabled' do
    procedure = described_class.new(
      account: create(:account),
      name: 'Sessão de fisioterapia',
      duration_minutes: 0,
      recurrence_allowed: true,
      max_sessions: nil
    )

    expect(procedure).not_to be_valid
    expect(procedure.errors[:duration_minutes]).to be_present
    expect(procedure.errors[:max_sessions]).to be_present
  end
end
