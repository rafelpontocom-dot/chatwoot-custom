class Marketing::Meta::SubscribePageService
  # Assinar `leadgen` e o que faz o Meta comecar a nos avisar de cada lead.
  # Enquanto isto nao roda, a conexao existe e nao chega nada.
  FIELD = 'leadgen'.freeze

  def initialize(connection:, page_id:)
    @connection = connection
    @page_id = page_id
  end

  def perform
    Marketing::Meta::GraphClient.request(
      :post, "/#{page_id}/subscribed_apps",
      subscribed_fields: FIELD, access_token: page_token
    )
    mark_subscribed(true)
  rescue Marketing::Meta::ApiError => e
    connection.mark_attention!(e)
    raise
  end

  def revoke
    Marketing::Meta::GraphClient.request(
      :delete, "/#{page_id}/subscribed_apps", access_token: page_token
    )
    mark_subscribed(false)
  end

  private

  attr_reader :connection, :page_id

  def page_token
    Marketing::Meta::PageTokenService.new(connection: connection, page_id: page_id).token
  end

  def mark_subscribed(subscribed)
    pages = Array(connection.settings['pages']).map do |page|
      page['id'].to_s == page_id.to_s ? page.merge('subscribed' => subscribed) : page
    end
    connection.update!(settings: connection.settings.merge('pages' => pages))
    subscribed
  end
end
