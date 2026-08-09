require 'rails_helper'

RSpec.describe KanbanCalendar::BackfillGoogleCalendarConnectionJob do
  it 'skips a disconnected Google Calendar connection' do
    connection = instance_double(KanbanCalendarGoogleConnection, connected?: false)
    allow(KanbanCalendarGoogleConnection).to receive(:find).with(91).and_return(connection)

    described_class.perform_now(91)

    expect(KanbanCalendarGoogleConnection).to have_received(:find).with(91)
  end
end
