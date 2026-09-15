class Calendar::GoogleCallbacksController < ApplicationController
  def show
    resource = KanbanCalendar::GoogleCalendarOauthService.resource_from_state!(params.require(:state))
    connection = KanbanCalendar::GoogleCalendarOauthService.new(resource: resource).connect!(params.require(:code))
    redirect_to calendar_url(connection.account_id, 'connected')
  rescue KanbanCalendar::GoogleCalendarPermissionError
    redirect_to calendar_url(resource&.account_id, 'permission_denied')
  rescue KanbanCalendar::GoogleCalendarApiError, ActionController::ParameterMissing, ActiveRecord::RecordNotFound
    # Com o `state` válido já se sabe a conta: quem recusou no Google volta à
    # agenda e vê o aviso, em vez de cair no início sem explicação.
    redirect_to calendar_url(resource&.account_id, 'error')
  end

  private

  def calendar_url(account_id, status)
    path = account_id ? "/app/accounts/#{account_id}/calendar" : '/app'
    "#{path}?google_calendar=#{status}"
  end
end
