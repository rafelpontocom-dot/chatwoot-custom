class Api::V1::Accounts::Calendar::SummariesController < Api::V1::Accounts::BaseController
  def show
    authorize KanbanCalendarAppointment, :index?
    render json: KanbanCalendar::AgendaSummary.new(account: Current.account).call
  end
end
