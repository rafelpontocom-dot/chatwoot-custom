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
    raise Marketing::Meta::ApiError, error_message(response) unless response.success?

    response.parsed_response
  rescue *NETWORK_ERRORS => e
    raise Marketing::Meta::ApiError, "Meta request failed: #{e.class.name}"
  end

  # O texto de erro do Meta pode conter id e nome de conta alheia; guardamos so
  # o que serve para diagnosticar.
  def self.error_message(response)
    error = response.parsed_response.is_a?(Hash) ? response.parsed_response['error'] : nil
    return "Meta responded #{response.code}" if error.blank?

    "Meta responded #{response.code}: #{error['type']} (#{error['code']})"
  end
end
