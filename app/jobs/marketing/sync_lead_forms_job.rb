class Marketing::SyncLeadFormsJob < ApplicationJob
  queue_as :low

  def perform(connection_id, page_id)
    connection = MarketingProviderConnection.find_by(id: connection_id)
    return if connection.blank? || !connection.status_connected?

    Marketing::Meta::SyncLeadFormsService.new(connection: connection, page_id: page_id).perform
  rescue Marketing::Meta::ApiError
    # O service ja marcou a conexao como `attention`; nao ha o que tentar de novo
    # a cada hora enquanto o token nao for renovado.
    nil
  end
end
