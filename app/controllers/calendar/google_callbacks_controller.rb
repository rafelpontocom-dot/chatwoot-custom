class Calendar::GoogleCallbacksController < ApplicationController
  def show
    connection = KanbanCalendar::GoogleCalendarOauthService.connect!(code: params.require(:code), state: params.require(:state))
    redirect_to calendar_url(connection.account_id, 'connected')
  rescue KanbanCalendar::GoogleCalendarApiError, ActionController::ParameterMissing, ActiveRecord::RecordNotFound
    redirect_to calendar_url(nil, 'error')
  end

  private

  def calendar_url(account_id, status)
    path = account_id ? "/app/accounts/#{account_id}/calendar" : '/app'
    "#{path}?google_calendar=#{status}"
  end
end
