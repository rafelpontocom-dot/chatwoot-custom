class Marketing::FlagExpiringConnectionsJob < ApplicationJob
  queue_as :low

  # O Meta nao emite refresh token: um token de pagina expira em ~60 dias e,
  # quando expira, os leads simplesmente param de chegar. Uma clinica so
  # descobre pela ausencia, dias depois. Marcar `attention` com uma semana de
  # folga e o que transforma isso num aviso na tela em vez de um sumico.
  def perform
    MarketingProviderConnection
      .connected
      .where.not(expires_at: nil)
      .where(expires_at: ..MarketingProviderConnection::RENEWAL_WINDOW.from_now)
      .find_each do |connection|
        connection.mark_attention!('token_expiring')
        # Marcar tira a conexao do escopo `connected`, entao a proxima hora nao
        # a encontra: e um email por vencimento, nao um por hora durante a
        # semana de folga.
        AdministratorNotifications::IntegrationsNotificationMailer
          .with(account: connection.account)
          .marketing_meta_token_expiring(connection)
          .deliver_later
      end
  end
end
