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
      .find_each { |connection| connection.mark_attention!('token_expiring') }
  end
end
