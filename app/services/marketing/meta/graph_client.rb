class Marketing::Meta::GraphClient
  include HTTParty

  API_VERSION = 'v21.0'.freeze
  base_uri "https://graph.facebook.com/#{API_VERSION}"

  REQUEST_TIMEOUT_SECONDS = 15
  NETWORK_ERRORS = [
    Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET,
    SocketError, OpenSSL::SSL::SSLError, HTTParty::Error
  ].freeze

  def self.request(method, path, params = {})
    response = public_send(method, path, query: params, timeout: REQUEST_TIMEOUT_SECONDS)
    raise_api_error(response) unless response.success?

    response.parsed_response
  rescue *NETWORK_ERRORS => e
    raise Marketing::Meta::ApiError, "Meta request failed: #{e.class.name}"
  end

  # O texto de erro do Meta pode conter id e nome de conta alheia; guardamos so
  # o que serve para diagnosticar, mais o codigo, que e o que a tela traduz em
  # "va dar controle total da pagina" em vez de "OAuthException (200)".
  def self.raise_api_error(response)
    error = response.parsed_response.is_a?(Hash) ? response.parsed_response['error'] : nil
    raise Marketing::Meta::ApiError, "Meta responded #{response.code}" if error.blank?

    code = error['code']
    raise Marketing::Meta::ApiError.new("Meta responded #{response.code}: #{error['type']} (#{code})", code: code)
  end
end
