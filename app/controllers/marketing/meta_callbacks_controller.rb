class Marketing::MetaCallbacksController < ApplicationController
  def show
    connection = Marketing::Meta::OauthService.connect!(code: params[:code], state: params[:state])
    redirect_to marketing_url(connection.account_id, 'connected'), allow_other_host: true
  rescue Marketing::Meta::ApiError, ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
    # O estado e de uso unico e ja foi consumido: sem ele nao ha conta para
    # onde voltar, entao a pessoa cai no app e ve o erro na propria tela.
    redirect_to "#{frontend_url}/app", allow_other_host: true
  end

  private

  def marketing_url(account_id, result)
    "#{frontend_url}/app/accounts/#{account_id}/marketing?meta=#{result}"
  end

  def frontend_url
    ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
  end
end
